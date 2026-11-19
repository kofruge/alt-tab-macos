import XCTest

final class SingleInstancePolicyTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SingleInstancePolicyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSamePathResolvesToSameLocation() {
        let path = "/Applications/AltTab.app"
        XCTAssertEqual(
            SingleInstancePolicy.resolveDuplicateLaunch(runningPath: path, launchedPath: path),
            .activateSameLocation)
    }

    func testTrailingSlashAndRelativeSegmentsResolveToSameLocation() {
        let running = "/Applications/AltTab.app"
        let launched = "/Applications/./Subdir/../AltTab.app/"
        XCTAssertEqual(
            SingleInstancePolicy.resolveDuplicateLaunch(runningPath: running, launchedPath: launched),
            .activateSameLocation)
    }

    func testSymlinkToSameBundleResolvesToSameLocation() throws {
        let realApp = tempDir.appendingPathComponent("Real/AltTab.app")
        let linkApp = tempDir.appendingPathComponent("Link/AltTab.app")
        try FileManager.default.createDirectory(at: realApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: linkApp.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: linkApp, withDestinationURL: realApp)

        XCTAssertEqual(
            SingleInstancePolicy.resolveDuplicateLaunch(runningPath: realApp.path, launchedPath: linkApp.path),
            .activateSameLocation)
    }

    func testDifferentDirectoriesResolveToDifferentLocation() {
        let running = "/Applications/AltTab.app/"
        let launched = "/Users/dev/DerivedData/Build/Products/Release/AltTab.app"
        XCTAssertEqual(
            SingleInstancePolicy.resolveDuplicateLaunch(runningPath: running, launchedPath: launched),
            .activateDifferentLocation(runningPath: "/Applications/AltTab.app"))
    }

    func testEmptyPathsAreTreatedDefensivelyAsDifferentLocation() {
        XCTAssertFalse(SingleInstancePolicy.isSameLocation(runningPath: "", launchedPath: ""))
        XCTAssertEqual(
            SingleInstancePolicy.resolveDuplicateLaunch(runningPath: "/Applications/AltTab.app", launchedPath: ""),
            .activateDifferentLocation(runningPath: "/Applications/AltTab.app"))
        XCTAssertEqual(
            SingleInstancePolicy.resolveDuplicateLaunch(runningPath: "", launchedPath: "/Applications/AltTab.app"),
            .activateDifferentLocation(runningPath: ""))
    }

    func testParseRestartingPidHandlesValidInvalidAndMissingFlags() {
        XCTAssertEqual(SingleInstancePolicy.parseRestartingPid(from: ["AltTab", "--restarting-pid=4210"]), 4210)
        XCTAssertEqual(
            SingleInstancePolicy.parseRestartingPid(from: ["AltTab", "--qa-permissions=granted", "--restarting-pid=99"]),
            99)
        XCTAssertNil(SingleInstancePolicy.parseRestartingPid(from: ["AltTab"]))
        XCTAssertNil(SingleInstancePolicy.parseRestartingPid(from: ["AltTab", "--restarting-pid="]))
        XCTAssertNil(SingleInstancePolicy.parseRestartingPid(from: ["AltTab", "--restarting-pid=abc"]))
        XCTAssertNil(SingleInstancePolicy.parseRestartingPid(from: ["AltTab", "--restarting-pid=0"]))
        XCTAssertNil(SingleInstancePolicy.parseRestartingPid(from: ["AltTab", "--restarting-pid=-12"]))
    }

    func testRestartArgumentRoundTripsThroughParser() {
        let arg = SingleInstancePolicy.restartArgument(for: 8192)
        XCTAssertEqual(arg, "--restarting-pid=8192")
        XCTAssertEqual(SingleInstancePolicy.parseRestartingPid(from: ["AltTab", arg]), 8192)
    }

    func testPayloadRoundTripAndCorruptInputs() {
        let payload = SingleInstancePolicy.DuplicateLaunchPayload(launchedFromPath: "/tmp/Build/AltTab.app")
        let encoded = SingleInstancePolicy.encodePayload(payload)
        XCTAssertNotNil(encoded)
        XCTAssertEqual(encoded.flatMap(SingleInstancePolicy.decodePayload), payload)
        XCTAssertNil(SingleInstancePolicy.decodePayload(Data()))
        XCTAssertNil(SingleInstancePolicy.decodePayload(Data("{not-json".utf8)))
    }

    func testNotificationContentFormatsAppNameAndRunningPath() {
        let content = SingleInstancePolicy.notificationContent(appName: "AltTab", runningPath: "/Applications/AltTab.app")
        XCTAssertEqual(content.title, "AltTab is already running")
        XCTAssertEqual(content.body, "Already running from /Applications/AltTab.app")
    }
}
