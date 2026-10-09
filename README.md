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
