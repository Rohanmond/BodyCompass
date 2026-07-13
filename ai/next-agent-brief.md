# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Completed Software Phase

Phase 7 weekly review, history trends, and standardized progress-photo check-ins are implemented and simulator-build verified.

## Best Next Phase

Implement Phase 8 database-backed persistence, private object storage, authentication/private-user mode, export, and complete deletion. First preserve the current local-first behavior and existing typed contracts.

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

Physical Watch, camera, HealthKit, and live-provider validation cannot be replaced by simulator compilation; keep those items accurately marked as pending.
