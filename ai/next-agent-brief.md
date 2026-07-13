# Next Agent Brief

## Best Next Phase

Continue Phase 4: Structured Training Plan.

## Recommended Scope

Build the first structured training loop:

- seed the user's weekly strength and swimming split,
- show today's detailed session,
- prescribe exercises, sets, rep ranges, RIR/RPE, rest, and substitutions,
- record completed sets and swimming work,
- create Coach routine-change proposals that require confirmation.

## Suggested Implementation

- Add pure routine, training-day, exercise-prescription, workout-log, and change-proposal models to `BodyCompassCore`.
- Seed Monday chest/triceps; Tuesday back/biceps plus swim; Wednesday legs; Thursday swim; Friday upper body; Saturday arms plus swim; Sunday swim.
- Add weekly routine and session-detail SwiftUI views.
- Implement a conservative double-progression rule using rep range and target RIR/RPE.
- Extend Coach responses with a validated structured proposal schema.
- Add Confirm, Edit, Reject, version history, and rollback behavior.
- Ask for training experience, equipment, limitations, and swimming intensity before generating the first detailed prescription.

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
