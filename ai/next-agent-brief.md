# Next Agent Brief

## Best Next Phase

Proceed with Phase 5: Meal Photo Logging.

## Recommended Scope

Build the first real meal capture and analysis loop:

- camera and photo-library input,
- portion and preparation notes,
- multipart upload to the backend,
- provider and reconciled result states,
- user correction before saving.

## Suggested Implementation

- Add a SwiftUI photo picker and camera capture flow to `MealLogView`.
- Resize images and remove metadata before upload.
- Add a typed iOS API client for `/api/meals/analyze`.
- Keep OpenAI and Gemini keys and provider calls on the backend.
- Add loading, low-confidence, provider-failure, correction, and retry states.
- Persist corrected results separately from raw provider estimates.

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
