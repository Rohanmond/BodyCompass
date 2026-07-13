# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Best Next Phase

Validate the Apple Workout-only Phase 4W path on the paired devices.

## Recommended Scope

On the user's paired Apple Watch Series 10 (watchOS 26.1) and iPhone (iOS 26.5):

- follow `docs/apple-watch-setup.md` and resolve signing/device-only issues,
- verify routine sync, WorkoutKit authorization, iPhone scheduling, Watch handoff, Apple Workout capture, HealthKit result import, and exact-once queued-log merge,
- add focused pure-model checks for any new sync reconciliation logic.

## Suggested Implementation

- Keep Apple Workout as the exclusive active-session owner.
- Keep Watch logs locally until an iPhone acknowledgement arrives.
- Merge by stable UUID; retransmission must never duplicate a set or swim.
- Do not infer reps or prescribe load changes from heart rate.
- Ask Pool/Open Water at handoff time; do not add a BodyCompass pool-length preference.
- Keep simulator-build success separate from physical-device validation in status docs.

## Do Not Expand This Slice Into

- custom BodyCompass `HKWorkoutSession` ownership or workout mirroring,
- AI recovery coaching,
- meal/photo or database work,
- silent Coach changes to the active routine.

## Verification

Run:

```sh
cd ios/BodyCompass
swift run BodyCompassCoreCheck
```

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

```sh
cd server
npm test
```

Also build the `BodyCompass Watch App` scheme for `generic/platform=watchOS Simulator`. Physical Watch validation cannot be replaced by simulator compilation.
