# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Completed Software Phase

Phase 8 SQLite persistence, photo-free single-user authentication, local-first backup, export, and deletion are implemented. The Railway production service is live with HTTPS and durable `/data`.

## Best Next Phase

Complete the Phase 9D authenticated iPhone checks and production restore drill, then proceed through paired Watch validation, the seven-day personal beta, and internal TestFlight.

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

Phase 9C camera/live-provider flows are user-confirmed on the signed iPhone. Production HTTPS is live and the app is configured for its Railway URL. Bearer-token iPhone checks, the host restore drill, physical Watch, and partial/denied HealthKit validation remain pending.
