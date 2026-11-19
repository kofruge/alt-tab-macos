#!/usr/bin/env bash

# ==============================================================================
# AltTab Build Automation Script
#
# WHAT:
#   Automates building, code-signing, optional installation, and execution of
#   AltTab for both Debug and Release configurations.
#
# WHY:
#   1. Headless Developer Workflow: Enables fast building and testing from the
#      terminal without opening the Xcode IDE interface.
#   2. Accessibility Permission Persistence: macOS TCC (Transparency, Consent,
#      and Control) ties granted Accessibility privileges to the binary's code
#      signature. Using an ad-hoc ("-") signature causes macOS to invalidate
#      permissions after every rebuild. This script ensures all builds are signed
#      with the stable "Local Self-Signed" certificate identity so permissions
#      persist seamlessly across incremental development builds.
#   3. Clean Deployment: Automates terminating running instances, copying the
#      built bundle into /Applications, and launching via the LaunchServices API.
# ==============================================================================

set -euo pipefail

# Default configuration is release
CONFIG="release"
LAUNCH=false
INSTALL=false

print_usage() {
  echo "Usage: ./build.sh [debug|release] [options]"
  echo ""
  echo "Arguments:"
  echo "  debug        Build Debug version (fast incremental build)"
  echo "  release      Build Release version (optimized production build, default)"
  echo ""
  echo "Options:"
  echo "  -r, --run        Launch the built app after building"
  echo "  -i, --install    Copy the built app to /Applications and launch it"
  echo "  -h, --help       Show this help message"
}

for arg in "$@"; do
  case "$arg" in
    debug)
      CONFIG="debug"
      ;;
    release)
      CONFIG="release"
      ;;
    -r|--run)
      LAUNCH=true
      ;;
    -i|--install)
      INSTALL=true
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      print_usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SIGNING_IDENTITY="Local Self-Signed"
if [ -n "${CI:-}" ]; then
  # What: In CI, check for a non-expired certificate in the temporary keychain without `-v`.
  # Why: CI self-signed certs live in a temporary keychain outside the system trust root, so `-v`
  # reports 0 valid identities even when codesigning works.
  all_identities="$(security find-identity -p codesigning 2>/dev/null || true)"
  if ! printf '%s\n' "$all_identities" | grep "\"$SIGNING_IDENTITY\"" | grep -vq "CSSMERR_TP_CERT_EXPIRED"; then
    echo "==> Setting up CI self-signed certificate..."
    ./scripts/codesign/setup_ci_pr.sh
  fi
else
  # What: Locally, require a valid, trusted, non-expired "Local Self-Signed" identity (`-v`).
  # Why: Expired or untrusted certs cause `codesign` to fail or leave the app ad-hoc signed,
  # breaking macOS TCC permission persistence across rebuilds.
  valid_identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if ! printf '%s\n' "$valid_identities" | grep -q "\"$SIGNING_IDENTITY\""; then
    all_identities="$(security find-identity -p codesigning 2>/dev/null || true)"
    if printf '%s\n' "$all_identities" | grep -q "\"$SIGNING_IDENTITY\""; then
      echo "Error: An expired or untrusted '$SIGNING_IDENTITY' certificate exists in your Keychain." >&2
      echo "Please open Keychain Access, search for '$SIGNING_IDENTITY' in the 'login' keychain, delete the expired certificate, and re-run ./build.sh." >&2
      exit 1
    fi
    echo "==> Setting up local self-signed certificate..."
    ./scripts/codesign/setup_local.sh
  fi
fi

# What: Ensure CI temporary keychain is unlocked prior to build and signing steps.
# Why: In headless CI runners, keychains can re-lock across separate shell invocations.
if [ -n "${CI:-}" ] || security list-keychains 2>/dev/null | grep -q "alt-tab-macos.keychain"; then
  security unlock-keychain -p password alt-tab-macos.keychain 2>/dev/null || true
fi

if [ "$CONFIG" = "debug" ]; then
  echo "==> Building AltTab (Debug)..."
  xcodebuild \
    -project alt-tab-macos.xcodeproj \
    -scheme Debug \
    -configuration Debug \
    -derivedDataPath DerivedData \
    build

  APP_PATH="DerivedData/Build/Products/Debug/AltTab.app"
else
  echo "==> Building AltTab (Release)..."
  xcodebuild \
    -project alt-tab-macos.xcodeproj \
    -scheme Release \
    -configuration Release \
    -derivedDataPath DerivedData \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    build

  APP_PATH="DerivedData/Build/Products/Release/AltTab.app"

  echo "==> Signing with '$SIGNING_IDENTITY' to preserve permissions..."
  codesign --force --sign "$SIGNING_IDENTITY" --deep --options runtime --entitlements alt_tab_macos.entitlements "$APP_PATH"
fi

echo ""
echo "==> Build successful: $APP_PATH"

stop_running_alttab() {
  pkill -x AltTab 2>/dev/null || true
  for _ in $(seq 1 50); do
    if ! pgrep -x AltTab >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
}

if [ "$INSTALL" = true ]; then
  echo "==> Installing to /Applications/AltTab.app..."
  stop_running_alttab
  rm -rf /Applications/AltTab.app
  cp -R "$APP_PATH" /Applications/AltTab.app
  echo "==> Launching /Applications/AltTab.app..."
  open /Applications/AltTab.app
elif [ "$LAUNCH" = true ]; then
  echo "==> Launching $APP_PATH..."
  stop_running_alttab
  open "$APP_PATH"
fi
