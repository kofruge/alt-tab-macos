#!/usr/bin/env bash

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
SIGNING_IDENTITY="Local Self-Signed"
if ! security find-identity -v -p codesigning | grep -q "\"$SIGNING_IDENTITY\""; then
  echo "==> Setting up local self-signed certificate..."
  ./scripts/codesign/setup_local.sh
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
