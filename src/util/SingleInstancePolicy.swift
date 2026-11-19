import Foundation

/// Pure single-instance decision logic shared between the app guard and unit tests.
///
/// Kept free of AppKit, Mach port, and UserNotifications dependencies so every branch can be
/// unit-tested deterministically without launching a bundled app host.
enum SingleInstancePolicy {
    static let restartingPidFlagPrefix = "--restarting-pid="

    struct DuplicateLaunchPayload: Codable, Equatable {
        let launchedFromPath: String
    }

    enum DuplicateLaunchOutcome: Equatable {
        case activateSameLocation
        case activateDifferentLocation(runningPath: String)
    }

    struct NotificationContent: Equatable {
        let title: String
        let body: String
    }

    /// Canonicalizes a bundle path by resolving symlinks and standardizing relative segments or
    /// trailing slashes so equivalent paths compare equal.
    static func canonicalPath(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// Returns true only when both paths are non-empty and resolve to the same bundle on disk.
    static func isSameLocation(runningPath: String, launchedPath: String) -> Bool {
        guard !runningPath.isEmpty && !launchedPath.isEmpty else { return false }
        return canonicalPath(runningPath) == canonicalPath(launchedPath)
    }

    /// Decides whether a duplicate launch came from the same bundle location (silent Settings
    /// activation) or a distinct bundle location (Settings activation + macOS notification).
    static func resolveDuplicateLaunch(runningPath: String, launchedPath: String) -> DuplicateLaunchOutcome {
        if isSameLocation(runningPath: runningPath, launchedPath: launchedPath) {
            return .activateSameLocation
        }
        return .activateDifferentLocation(runningPath: canonicalPath(runningPath))
    }

    /// Extracts the positive PID passed by `App.restart()` so the relaunched process waits for the
    /// outgoing instance to drain captures and release the single-instance lock.
    static func parseRestartingPid(from arguments: [String]) -> pid_t? {
        guard let flag = arguments.first(where: { $0.hasPrefix(restartingPidFlagPrefix) }) else {
            return nil
        }
        let raw = flag.dropFirst(restartingPidFlagPrefix.count)
        guard let pid = pid_t(raw), pid > 0 else { return nil }
        return pid
    }

    static func restartArgument(for pid: pid_t) -> String {
        "\(restartingPidFlagPrefix)\(pid)"
    }

    static func notificationContent(appName: String, runningPath: String) -> NotificationContent {
        let title = String(
            format: NSLocalizedString("%@ is already running", comment: "Duplicate launch notification title; %@ is AltTab"),
            appName)
        let body = String(
            format: NSLocalizedString("Already running from %@", comment: "Duplicate launch notification body; %@ is the running app path"),
            runningPath)
        return NotificationContent(title: title, body: body)
    }

    static func encodePayload(_ payload: DuplicateLaunchPayload) -> Data? {
        try? JSONEncoder().encode(payload)
    }

    static func decodePayload(_ data: Data) -> DuplicateLaunchPayload? {
        try? JSONDecoder().decode(DuplicateLaunchPayload.self, from: data)
    }
}
