# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Best Next Phase

Implement Phase 6 contextual Coach Chat. Paired-device Watch validation remains a separate hardware task.

## Recommended Scope

- Add a typed iOS chat client and conversation states.
- Send profile, latest health snapshot, accepted meals, adherence, goal projection, and active training version as bounded context.
- Replace mock chat calls with real OpenAI and Gemini adapters while retaining no-key mocks and one-provider fallback.
- Add medical/injury/extreme-deficit/eating-disorder safety routing.
- Preserve combined and raw provider answers.
- Convert routine-change suggestions into the existing `RoutineChangeProposal`; never activate a change directly from chat.

## Suggested Implementation

- Reuse meal-provider transport and error patterns where they fit.
- Bound context size and exclude meal image bytes from chat payloads.
- Keep API keys backend-only and model names environment-configurable.
- Return one concrete next action in the reconciled answer.
- Reuse proposal validation, staleness, diff, and Confirm/Edit/Reject behavior already owned by `TrainingStore`.

## Do Not Expand This Slice Into

- database/auth work,
- progress-photo analysis,
- changes to Apple Workout ownership,
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

Physical Watch, camera, and live-key validation cannot be replaced by simulator compilation; keep those items accurately marked as pending.
