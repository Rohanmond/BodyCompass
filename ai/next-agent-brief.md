# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Best Next Phase

Proceed with Phase 5: Meal Photo Logging.

## Recommended Scope

Build the first complete meal capture loop:

- choose a meal image from Photos,
- capture portion and preparation notes,
- upload through a typed iOS API client,
- show OpenAI, Gemini, and reconciled estimates,
- let the user correct and persist the accepted meal.

## Suggested Implementation

- Add PhotosPicker first; camera capture requires real-device verification.
- Resize the selected image and remove metadata before upload.
- Add a typed client for `/api/meals/analyze` while keeping backend mock mode operational without API keys.
- Model loading, retry, low-confidence, and one-provider-failure states.
- Preserve raw provider estimates and store the user-corrected result separately.
- Persist accepted meals locally and show a basic history.
- Keep API keys backend-only.

## Do Not Expand This Slice Into

- real OpenAI or Gemini calls,
- database/auth work,
- Apple Watch Phase 4W unless the user explicitly prioritizes it and supplies device details,
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
