#!/usr/bin/env bash
#
# Builds Toast Duo.app from the SwiftPM package.
#
#   ./build.sh            build and sign
#   ./build.sh --run      build, sign, and relaunch the app
#   ./build.sh --universal  build for Apple Silicon and Intel
#   ./build.sh --install  build, sign, move into /Applications, and relaunch
#
# Signs with the first Apple Development identity in the keychain, so Screen
# Recording permission survives rebuilds. Without one it signs ad-hoc, and
# macOS may ask for the permission again after every rebuild. Set
# SIGN_IDENTITY to choose an identity, or to - for ad-hoc.

set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${SIGN_IDENTITY+set}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/"Apple Development: / { print $2; exit }')"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
APP_NAME="Toast Duo"
BUNDLE="build/${APP_NAME}.app"

BUILD_ARGS=(-c release)
RUN_APP=false
INSTALL_APP=false
for argument in "$@"; do
  case "$argument" in
    --universal) BUILD_ARGS+=(--arch arm64 --arch x86_64) ;;
    --run) RUN_APP=true ;;
    --install) INSTALL_APP=true ;;
    *) echo "Unknown argument: $argument" >&2; exit 1 ;;
  esac
done

swift build "${BUILD_ARGS[@]}" --product MacDuo
swift build "${BUILD_ARGS[@]}" --product lidprobe

BIN_PATH="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BINARY="$BIN_PATH/MacDuo"
PROBE="$BIN_PATH/lidprobe"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/MacDuo"
# SwiftPM resolves Bundle.module relative to the application bundle.
cp -R "$BIN_PATH/MacDuo_MacDuo.bundle" "$BUNDLE/Contents/Resources/"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp LICENSE NOTICE "$BUNDLE/Contents/Resources/"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
fi
cp "$PROBE" build/lidprobe

TIMESTAMP=--timestamp
if [[ "$SIGN_IDENTITY" == - ]]; then
  TIMESTAMP=--timestamp=none
fi
codesign --force --options runtime "$TIMESTAMP" \
  --sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --strict --verbose=1 "$BUNDLE"

echo "built ${BUNDLE}"
codesign -dv "$BUNDLE" 2>&1 | grep -E "Identifier|TeamIdentifier|Signature" || true

if "$INSTALL_APP"; then
  INSTALLED="/Applications/${APP_NAME}.app"
  pkill -f "^$INSTALLED/Contents/MacOS/MacDuo( |$)" 2>/dev/null || true
  sleep 0.5
  rm -rf "$INSTALLED"
  ditto "$BUNDLE" "$INSTALLED"
  # One copy only, so Launch Services and the login item find this one.
  rm -rf "$BUNDLE"
  codesign --verify --strict "$INSTALLED"
  open "$INSTALLED"
  echo "installed ${INSTALLED}"
fi

if "$RUN_APP"; then
  pkill -f "^$PWD/$BUNDLE/Contents/MacOS/MacDuo( |$)" 2>/dev/null || true
  sleep 0.5
  open "$BUNDLE"
  echo "launched"
fi
