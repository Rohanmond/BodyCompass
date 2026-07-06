# Phase 1: Xcode Setup Guide

Phase 1 turns the Swift files into a real Xcode iOS project.

## What Was Added

- `ios/BodyCompass/BodyCompass.xcodeproj`
- Shared `BodyCompass` scheme
- iOS app target named `BodyCompass`
- App Info.plist with camera, photo library, and HealthKit usage text
- HealthKit entitlements file
- Placeholder asset catalog and AppIcon slot

## How to Open the App

1. Open Xcode.
2. Choose **File > Open**.
3. Open:

```text
/Users/rohanmondal/code/BodyCompass/ios/BodyCompass/BodyCompass.xcodeproj
```

4. Select the `BodyCompass` scheme at the top.
5. Select an iPhone simulator.
6. Press the Run button.

## First-Time Xcode Settings

If signing fails:

1. Click the `BodyCompass` project in the left sidebar.
2. Select the `BodyCompass` target.
3. Open **Signing & Capabilities**.
4. Choose your Apple developer team.
5. Keep **Automatically manage signing** enabled.
6. Confirm **HealthKit** is present under capabilities.

## Terminal Build Setup

Your Mac has Xcode installed, but the terminal developer path may point to Command Line Tools. If `xcodebuild` says it requires Xcode, run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then check:

```sh
xcodebuild -version
xcrun simctl list devices available
```

To verify the project builds from the repo:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/BodyCompass/BodyCompass.xcodeproj \
  -scheme BodyCompass \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/BodyCompass/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Important Beginner Notes

- The Xcode project builds the app UI.
- The Swift package still exists for command-line verification of core logic.
- HealthKit works best on a real iPhone.
- Camera/photo permissions are included now, but the actual photo picker is Phase 5.
- API keys still belong only in the backend, never in Xcode.
