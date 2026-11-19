# SingleInstancePolicy — Specs

## Summary

AltTab enforces a single running instance across bundle locations (for example `/Applications/AltTab.app`,
`DerivedData/Build/Products/.../AltTab.app`, or `~/Downloads/AltTab.app`) in both Debug and Release builds.

When a second instance launches while another copy is already running, the running instance always wins:
- Same bundle path: activates the running instance and shows Settings (or Permissions if still waiting on grants).
- Different bundle path: activates the running instance, shows Settings (or Permissions), and posts a macOS
  Notification Center (`UNUserNotificationCenter`) banner naming the running path. Clicking the banner focuses
  Settings (or Permissions).
- The duplicate copy exits before initializing AppKit, event taps, or `MoveToApplicationsFolder`.

## Why exiting duplicates bypass `App.terminate`

`App.applicationWillTerminate` and `emergencyExit` call `setNativeCommandTabEnabled(true)`, which re-enables
macOS's built-in Cmd+Tab switcher on behalf of the terminating process. A duplicate instance must therefore
exit via `Darwin.exit(0)` before `App.shared.run()` and before installing signal handlers, leaving the active
instance's global hotkey interception intact.

## Invariants

- **Single-instance before Move-to-Applications**: `SingleInstanceGuard.acquireOrExit()` runs in `main.swift`
  immediately after CLI/QA-cleanup arguments and before `App.shared.run()`, so a second copy launched from a
  build or download folder never presents "Move to Applications folder?".
- **CLI & QA exemptions**:
  - `--qa-lifecycle-cleanup=` exits before single-instance locking.
  - `CliClient` commands (`--list`, `--qa-state`, etc.) talk to `.cli` and exit before single-instance locking.
- **Controlled restarts (`App.restart()`)**: `App.restart()` passes `--restarting-pid=<pid>` to the new
  process. `SingleInstanceGuard` waits up to 6.5s for that PID to exit (covering the 5s capture-drain timeout
  in `makeSureAllCapturesAreFinished`) before claiming the `<bundleId>.instance` Mach port.
- **Canonical path comparison**: Symlinks, relative segments (`..`, `.`), and trailing slashes are resolved so
  two paths to the same `.app` bundle never trigger a false "other location" notification.
- **Notifications**: `UNUserNotificationCenter` authorization (`[.alert]`) is requested once on startup after
  Accessibility/Screen Recording grants (skipped in QA runs), with a foreground `UNUserNotificationCenterDelegate`
  returning `[.banner]` so the banner still displays when Settings is activated.

## Scenarios

- **testSamePathResolvesToSameLocation** — identical paths stay silent on duplicate launch.
- **testTrailingSlashAndRelativeSegmentsResolveToSameLocation** — unstandardized equivalent paths match.
- **testSymlinkToSameBundleResolvesToSameLocation** — symlinks resolve to the same canonical `.app` path.
- **testDifferentDirectoriesResolveToDifferentLocation** — distinct bundle locations trigger the notification
  outcome carrying the canonical running path.
- **testEmptyPathsAreTreatedDefensivelyAsDifferentLocation** — empty/malformed paths never crash or match.
- **testParseRestartingPidHandlesValidInvalidAndMissingFlags** — validates `--restarting-pid=` parsing across
  happy path, missing flag, zero/negative PIDs, non-numeric input, and combined CLI flags.
- **testRestartArgumentRoundTripsThroughParser** — `restartArgument(for:)` round-trips via `parseRestartingPid`.
- **testPayloadRoundTripAndCorruptInputs** — encodes/decodes `DuplicateLaunchPayload` and rejects corrupt/empty
  data cleanly.
- **testNotificationContentFormatsAppNameAndRunningPath** — verifies user-facing title and body formatting.
