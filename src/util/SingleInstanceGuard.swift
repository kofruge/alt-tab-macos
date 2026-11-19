import Cocoa
import Darwin
import UserNotifications

/// Enforces single-instance execution across bundle locations and coordinates activation +
/// UserNotifications alerts when a duplicate copy is launched.
enum SingleInstanceGuard {
    private static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.lwouis.alt-tab-macos"
    }

    private static var portName: String { "\(bundleIdentifier).instance" }
    private static var notificationId: String { "\(bundleIdentifier).already-running" }
    private static let portQueue = DispatchQueue(label: "single-instance")
    private static let ackData = Data("ok".utf8)
    private static var localPort: CFMessagePort?
    private static let notificationDelegate = NotificationDelegate()

    private static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    /// Acquires the process-wide single-instance Mach port or delegates to the already-running
    /// copy and exits before AppKit initializes.
    static func acquireOrExit() {
        let restartingPid = SingleInstancePolicy.parseRestartingPid(from: CommandLine.arguments)
        if let restartingPid {
            waitForProcessToExit(restartingPid, timeout: 6.5)
        }
        guard let port = createLocalPort(retryOnRestart: restartingPid != nil) else {
            notifyRunningInstanceAndExit()
        }
        localPort = port
        CFMessagePortSetDispatchQueue(port, portQueue)
        if waitIfLegacyOrRivalInstanceRemains(excluding: restartingPid) {
            CFMessagePortInvalidate(port)
            localPort = nil
            activateFallbackRunningInstance(excluding: restartingPid)
            // Must bypass App.terminate / emergencyExit because those re-enable native Cmd+Tab.
            Darwin.exit(0)
        }
    }

    static func installNotificationDelegate() {
        guard isBundledApp else { return }
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    static func requestNotificationAuthorizationIfNeeded() {
        guard isBundledApp else { return }
        #if DEBUG
        guard !QaLifecycle.enabled && !Preferences.qaPristine else { return }
        #endif
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert]) { _, error in
                if let error {
                    Logger.warning { "Notification authorization failed: \(error.localizedDescription)" }
                }
            }
        }
    }

    static func postAlreadyRunningNotification(runningPath: String) {
        guard isBundledApp else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                scheduleNotification(on: center, runningPath: runningPath)
            case .notDetermined:
                center.requestAuthorization(options: [.alert]) { granted, error in
                    if let error {
                        Logger.warning { "Notification authorization failed: \(error.localizedDescription)" }
                    }
                    if granted {
                        scheduleNotification(on: center, runningPath: runningPath)
                    }
                }
            default:
                Logger.info { "Skipping duplicate-launch notification; permission status is \(settings.authorizationStatus.rawValue)" }
            }
        }
    }

    private static func scheduleNotification(on center: UNUserNotificationCenter, runningPath: String) {
        let content = UNMutableNotificationContent()
        let copy = SingleInstancePolicy.notificationContent(appName: App.name, runningPath: runningPath)
        content.title = copy.title
        content.body = copy.body
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                Logger.warning { "Failed to deliver duplicate-launch notification: \(error.localizedDescription)" }
            }
        }
    }

    private static func createLocalPort(retryOnRestart: Bool) -> CFMessagePort? {
        let attempts = retryOnRestart ? 8 : 1
        for attempt in 0..<attempts {
            var context = CFMessagePortContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
            if let port = CFMessagePortCreateLocal(nil, portName as CFString, handlePortMessage, &context, nil) {
                return port
            }
            if attempt + 1 < attempts {
                usleep(25_000)
            }
        }
        return nil
    }

    private static func notifyRunningInstanceAndExit() -> Never {
        if let remotePort = connectToRemotePort() {
            let payload = SingleInstancePolicy.DuplicateLaunchPayload(launchedFromPath: Bundle.main.bundlePath)
            if let data = SingleInstancePolicy.encodePayload(payload) {
                var returnData: Unmanaged<CFData>?
                let status = CFMessagePortSendRequest(
                    remotePort, 0, data as CFData, 2.0, 2.0,
                    CFRunLoopMode.defaultMode.rawValue, &returnData)
                _ = returnData?.takeRetainedValue()
                if status == kCFMessagePortSuccess {
                    // Bypass App.terminate / emergencyExit so the active instance's Cmd+Tab tap stays intact.
                    Darwin.exit(0)
                }
            }
        }
        activateFallbackRunningInstance(excluding: nil)
        Darwin.exit(0)
    }

    private static func connectToRemotePort() -> CFMessagePort? {
        for attempt in 0..<5 {
            if let port = CFMessagePortCreateRemote(nil, portName as CFString) {
                return port
            }
            if attempt + 1 < 5 {
                usleep(20_000)
            }
        }
        return nil
    }

    private static let handlePortMessage: CFMessagePortCallBack = { _, _, data, _ in
        let launchedPath: String
        if let rawData = data as Data?, let payload = SingleInstancePolicy.decodePayload(rawData) {
            launchedPath = payload.launchedFromPath
        } else {
            launchedPath = ""
        }
        let outcome = SingleInstancePolicy.resolveDuplicateLaunch(
            runningPath: Bundle.main.bundlePath,
            launchedPath: launchedPath)
        DispatchQueue.main.async {
            App.handleDuplicateLaunch(outcome)
        }
        return Unmanaged.passRetained(ackData as CFData)
    }

    private static func waitForProcessToExit(_ pid: pid_t, timeout: TimeInterval) {
        let selfPid = ProcessInfo.processInfo.processIdentifier
        guard pid > 0, pid != selfPid else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while isProcessAlive(pid) && Date() < deadline {
            usleep(50_000)
        }
    }

    private static func isProcessAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private static func otherRunningInstances(excluding restartingPid: pid_t?) -> [NSRunningApplication] {
        let selfPid = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).filter { app in
            app.processIdentifier != selfPid
                && app.processIdentifier != restartingPid
                && !app.isTerminated
        }
    }

    /// Waits briefly when another instance is visible alongside our newly acquired lock: either it is
    /// a simultaneous peer finishing its exit path, or an older build without the `.instance` port.
    private static func waitIfLegacyOrRivalInstanceRemains(excluding restartingPid: pid_t?) -> Bool {
        guard !otherRunningInstances(excluding: restartingPid).isEmpty else { return false }
        for _ in 0..<10 {
            usleep(25_000)
            if otherRunningInstances(excluding: restartingPid).isEmpty {
                return false
            }
        }
        return true
    }

    private static func activateFallbackRunningInstance(excluding restartingPid: pid_t?) {
        guard let other = otherRunningInstances(excluding: restartingPid).first else { return }
        if let bundleURL = other.bundleURL {
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [bundleURL.path]
            do {
                try task.run()
                task.waitUntilExit()
                if task.terminationStatus == 0 { return }
            } catch {
                // Fall back to direct NSRunningApplication activation below if `/usr/bin/open` fails to spawn.
                FileHandle.standardError.write(Data("Failed to invoke /usr/bin/open fallback: \(error)\n".utf8))
            }
        }
        other.activate(options: .activateAllWindows)
    }

    private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            // Keep showing the auto-dismissing banner even though AltTab just activated Settings.
            completionHandler([.banner])
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            DispatchQueue.main.async {
                App.showSettingsWindowOrPermissions()
            }
            completionHandler()
        }
    }
}
