# Next Agent Brief

## Best Next Phase

Proceed with Phase 2: Profile and Goal Setup.

## Recommended Scope

Build onboarding and editable profile state:

- age,
- height,
- current weight,
- current body-fat estimate,
- target body-fat percentage,
- adherence baseline,
- optional weekly trend.

Then replace the hardcoded mock profile in `AppStore` with persisted local state.

## Suggested Implementation

- Add `OnboardingView`.
- Add simple local persistence using `UserDefaults` with Codable JSON for MVP.
- Add an edit profile screen under Goal.
- Keep `BodyProfile` in `BodyCompassCore`.
- Recalculate `GoalProjection` whenever profile changes.
- Update `docs/phases.md` and `/ai/implementation-status.md`.

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
