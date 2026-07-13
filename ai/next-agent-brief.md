# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Completed Software Phase

Phase 8 SQLite persistence, photo-free multi-user accounts, local-first backup, export, deletion, passwordless email OTP, and per-user AI quotas are implemented. Railway HTTPS, durable `/data`, and production Resend OTP are live and signed-iPhone verified. The production database was intentionally reset to an empty state on July 14, 2026.

## Best Next Phase

Run a clean-account signed-iPhone pass: OTP, blank onboarding, backup, export, AI allowance/live AI, sign out/re-entry, and account deletion. Then complete the Phase 9D host restore drill and paired Watch validation.

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

Phase 9C camera/live-provider flows and production OTP are user-confirmed on the signed iPhone. Email verification is intrinsic to OTP and password recovery is unnecessary because no password exists. Post-reset clean-account checks, the host restore drill, physical Watch, and partial/denied HealthKit validation remain pending.
