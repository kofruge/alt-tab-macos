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

# Verify Local Self-Signed certificate exists
# What: Checks whether the "Local Self-Signed" identity exists in any accessible keychain.
# Why: `security find-identity -v` requires certificates to pass system trust policy evaluation
# (i.e. signed by Apple Root CA or present in system root trust store). Self-signed certificates
# generated in CI environments are not in the system trust root, causing `-v` to report 0 valid
# identities even when the certificate and private key are fully present and usable for codesigning.
# Omitting `-v` ensures both local and CI environments detect the certificate correctly.
SIGNING_IDENTITY="Local Self-Signed"
if ! security find-identity -p codesigning | grep -q "\"$SIGNING_IDENTITY\""; then
  if [ -n "${CI:-}" ]; then
    echo "==> Setting up CI self-signed certificate..."
    ./scripts/codesign/setup_ci_pr.sh
  else
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

if [ "$INSTALL" = true ]; then
  echo "==> Installing to /Applications/AltTab.app..."
  pkill -x AltTab 2>/dev/null || true
  rm -rf /Applications/AltTab.app
  cp -R "$APP_PATH" /Applications/AltTab.app
  echo "==> Launching /Applications/AltTab.app..."
  open /Applications/AltTab.app
elif [ "$LAUNCH" = true ]; then
  echo "==> Launching $APP_PATH..."
  pkill -x AltTab 2>/dev/null || true
  open "$APP_PATH"
fi
