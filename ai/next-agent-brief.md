# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Best Next Phase

Continue Phase 4: Structured Training Plan.

## Recommended Scope

Build the structured training foundation:

- seed the user's weekly strength and swimming split,
- show today's detailed session,
- define versioned routine and workout-log models,
- persist and display the seeded split,
- establish deterministic progression and proposal state rules.

## Suggested Implementation

- Add pure routine, training-day, exercise-prescription, workout-log, and change-proposal models to `BodyCompassCore`.
- Seed Monday chest/triceps; Tuesday back/biceps plus swim; Wednesday legs; Thursday swim; Friday upper body; Saturday arms plus swim; Sunday swim.
- Add weekly routine and today's-session SwiftUI views reachable from Today.
- Add local `UserDefaults` persistence using Codable JSON, consistent with the current MVP.
- Keep generic daily `ScheduleItem` data separate from training data.
- Implement a conservative double-progression rule using rep range and target RIR/RPE.
- Define a validated pending proposal model with Confirm, Edit, and Reject transitions; keep provider calls mocked.
- Ask for training experience, equipment, limitations, and swimming intensity before generating the first detailed prescription.

## Do Not Expand This Slice Into

- real OpenAI or Gemini calls,
- database/auth work,
- meal photo capture,
- progress photo capture,
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
