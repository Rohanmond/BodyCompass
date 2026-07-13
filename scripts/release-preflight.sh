#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROJECT="$ROOT/ios/BodyCompass/BodyCompass.xcodeproj"
APP_ICON="$ROOT/ios/BodyCompass/App/Resources/Assets.xcassets/AppIcon.appiconset/BodyCompass-AppIcon.png"
WATCH_ICON="$ROOT/ios/BodyCompass/WatchApp/Resources/Assets.xcassets/AppIcon.appiconset/BodyCompass-Watch-AppIcon.png"
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
CACHE_ROOT=${TMPDIR:-/tmp}/bodycompass-preflight-cache
export DEVELOPER_DIR
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$CACHE_ROOT/swiftpm"

mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

say() {
    printf '\n==> %s\n' "$1"
}

say "Checking required tools"
command -v node >/dev/null
command -v npm >/dev/null
command -v swift >/dev/null
command -v xcodebuild >/dev/null
node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (major < 22 || (major === 22 && minor < 5)) { throw new Error("Node 22.5 or newer is required") }'

say "Validating release metadata"
plutil -lint \
    "$ROOT/ios/BodyCompass/App/Info.plist" \
    "$ROOT/ios/BodyCompass/App/PrivacyInfo.xcprivacy" \
    "$ROOT/ios/BodyCompass/WatchApp/Info.plist" \
    "$ROOT/ios/BodyCompass/WatchApp/PrivacyInfo.xcprivacy"

for icon in "$APP_ICON" "$WATCH_ICON"; do
    test -f "$icon"
    test "$(sips -g pixelWidth "$icon" | awk '/pixelWidth/ { print $2 }')" = "1024"
    test "$(sips -g pixelHeight "$icon" | awk '/pixelHeight/ { print $2 }')" = "1024"
    test "$(sips -g hasAlpha "$icon" | awk '/hasAlpha/ { print $2 }')" = "no"
done

say "Running backend tests"
(cd "$ROOT/server" && npm test)

say "Running Swift core checks"
(cd "$ROOT/ios/BodyCompass" && swift run --disable-sandbox BodyCompassCoreCheck)

if [ "${1:-}" = "--build" ]; then
    say "Building the iOS simulator target"
    xcodebuild -project "$PROJECT" -scheme BodyCompass -destination 'generic/platform=iOS Simulator' -derivedDataPath "$CACHE_ROOT/DerivedData-iOS" CODE_SIGNING_ALLOWED=NO build

    say "Building the watchOS simulator target"
    xcodebuild -project "$PROJECT" -scheme 'BodyCompass Watch App' -destination 'generic/platform=watchOS Simulator' -derivedDataPath "$CACHE_ROOT/DerivedData-watchOS" CODE_SIGNING_ALLOWED=NO build
fi

say "Preflight passed"
