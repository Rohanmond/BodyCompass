# Next Agent Brief

Read `ai/HANDOFF.md` before starting. This brief intentionally covers only the next implementation slice.

## Best Next Phase

Implement Phase 7 weekly review, history trends, and standardized progress-photo check-ins.

## Recommended Scope

- Add useful weight, body-fat, adherence, calories/protein, and workout trend views from existing local data.
- Add a once-weekly morning check-in flow with front, side, and back capture guidance and comparability checks.
- Re-render images before upload to strip metadata and keep originals in protected private local storage.
- Add a bounded progress-analysis endpoint that calls OpenAI and Gemini and returns broad body-fat ranges, visible trend, limitations, and one next-week action.
- Preserve raw provider outputs and a reconciled result. Allow the user to reject or correct an estimate.
- Compare only sufficiently standardized current/prior check-ins and prefer direction over false precision.

## Safety And Privacy

- Never return an exact body-fat measurement from photos; use a broad non-clinical range and confidence.
- Never identify the person, judge attractiveness, infer unrelated sensitive traits, or diagnose conditions.
- Avoid the face where practical, never use public URLs, and make every local photo/check-in deletable.
- API keys remain backend-only and model names remain environment-configurable.

## Keep Separate

- Phase 8 database/auth/object-storage work.
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
