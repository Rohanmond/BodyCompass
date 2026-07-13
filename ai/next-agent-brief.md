# Next Agent Brief

## Best Next Phase

Proceed with Phase 3: HealthKit Daily Sync.

## Recommended Scope

Read the user's daily Apple Health metrics and merge them with manual fallback values:

- steps,
- active energy,
- weight,
- body-fat percentage,
- sleep,
- workouts,
- resting heart rate.

## Suggested Implementation

- Expand `HealthKitService` with async queries for each supported metric.
- Add authorization and missing-data states to the Today screen.
- Keep manual entry available when a HealthKit value is unavailable.
- Update the persisted profile when newer weight or body-fat readings are available.
- Add focused tests around merging partial HealthKit data.

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
