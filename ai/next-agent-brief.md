# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Completed Software Phase

Phase 8 SQLite persistence, private encrypted images, single-user authentication, local-first backup, export, and deletion are implemented and simulator-build verified.

## Best Next Phase

Proceed to Phase 9 polish and beta readiness: accessibility, reliability and retry UX, real-device testing, app icon work, privacy/setup review, and TestFlight preparation. Keep production deployment/backup validation as an explicit Phase 8 operations track.

## Safety And Privacy

- Never return an exact body-fat measurement from photos; use a broad non-clinical range and confidence.
- Never identify the person, judge attractiveness, infer unrelated sensitive traits, or diagnose conditions.
- Avoid the face where practical, never use public URLs, and make every local photo/check-in deletable.
- API keys remain backend-only and model names remain environment-configurable.

## Keep Separate

- Apple Workout ownership or Watch connectivity changes.
- Silent routine changes from Coach.

## Verification

Run:

```sh
cd ios/BodyCompass
swift run --disable-sandbox BodyCompassCoreCheck
```

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/BodyCompass/BodyCompass.xcodeproj \
  -scheme BodyCompass \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/BodyCompassDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```sh
cd server
npm test
```

Phase 9C camera/live-provider flows are user-confirmed on the signed iPhone. Physical Watch and partial/denied HealthKit validation cannot be replaced by simulator compilation and remain pending.
