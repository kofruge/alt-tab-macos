<div align="center">

<a href="https://alt-tab.app/"><img src="docs/readme/main.svg" alt="AltTab Pro — 7.4M downloads — 15K GitHub stars — Get AltTab"/></a>

<a href="https://jb.gg/OpenSource"><img src="docs/readme/sponsor.svg" alt="Sponsored by JetBrains" width="900"/></a>

</div>

## Hidden Settings (`defaults`)

You can configure advanced options in Terminal using macOS `defaults write com.lwouis.alt-tab-macos <key> <value>`.

### Key Repeat Speed

By default, AltTab matches macOS's system key repeat settings (`KeyRepeat` and `InitialKeyRepeat`). You can override them specifically for AltTab:

- **Repeat Interval** (`keyRepeatInterval`): Time between repeats in seconds (e.g. `0.05` for 20 repeats/sec):
  ```bash
  defaults write com.lwouis.alt-tab-macos keyRepeatInterval -float 0.05
  ```

- **Initial Delay** (`keyRepeatInitialDelay`): Delay in seconds before repeat starts when holding a key:
  ```bash
  defaults write com.lwouis.alt-tab-macos keyRepeatInitialDelay -float 0.2
  ```

- **Reset to System Settings**:
  ```bash
  defaults delete com.lwouis.alt-tab-macos keyRepeatInterval
  defaults delete com.lwouis.alt-tab-macos keyRepeatInitialDelay
  ```

### Two-Finger Trackpad Scrolling

- **Scroll Acceleration** (`twoFingerScrollAccelerationEnabled`): Disables macOS scroll acceleration and momentum inertia for trackpad scrolling, keeping selection movement linear:
  ```bash
  defaults write com.lwouis.alt-tab-macos twoFingerScrollAccelerationEnabled -bool false
  ```
  To re-enable acceleration:
  ```bash
  defaults write com.lwouis.alt-tab-macos twoFingerScrollAccelerationEnabled -bool true
  # or
  defaults delete com.lwouis.alt-tab-macos twoFingerScrollAccelerationEnabled
  ```

- **Scroll Step Distance** (`twoFingerScrollStepThreshold`): Points of trackpad movement needed to step to the next window (default: `20.0`):
  ```bash
  defaults write com.lwouis.alt-tab-macos twoFingerScrollStepThreshold -float 20.0
  ```

### Scrollbar Visibility

By default, the vertical scrollbar is visible during scrolling. If you prefer to completely disable or hide the scrollbar so it never appears or overlaps the list:

- **Hide Scrollbar** (`hideScrollbar`):
  ```bash
  defaults write com.lwouis.alt-tab-macos hideScrollbar -bool true
  ```

- **Show Scrollbar** (restore default):
  ```bash
  defaults write com.lwouis.alt-tab-macos hideScrollbar -bool false
  # or
  defaults delete com.lwouis.alt-tab-macos hideScrollbar
  ```

---

## Building Releases with GitHub Actions CI

A dedicated GitHub Actions workflow is provided at `.github/workflows/release.yml` to compile and package universal binaries on macOS CI runners without requiring developer secrets.

### Option 1: Manual Trigger via GitHub Web UI

1. Go to your fork's repository on GitHub.
2. Click on the **Actions** tab.
3. Select **Build Release** in the sidebar.
4. Click **Run workflow**:
   - Optionally enter a version tag (e.g. `v7.0.0-mini.1`).
   - Toggle whether to create a formal GitHub Release or just save the `.zip` as a workflow artifact.
5. Once completed (~3-4 minutes), the release `.zip` and `.sha256` checksum will be attached to the run artifacts and published as a GitHub Release.

### Option 2: Automatic Trigger on Git Tag

Pushing any version tag starting with `v` automatically triggers a release build and publishes it:

```bash
git tag v11.9.0-mini.1
git push origin v11.9.0-mini.1
```
