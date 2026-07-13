# BodyCompass Beta Checklist

Use this checklist after Phase 9 code passes locally. A simulator can verify layout and compilation, but HealthKit, camera, Watch connectivity, WorkoutKit handoff, and notifications need your signed physical devices.

## 1. Run the automated preflight

From the repository root:

```sh
./scripts/release-preflight.sh --build
```

This validates the privacy files and icon, runs backend and Swift core checks, and builds both simulator targets. It does not upload anything.

## 2. Configure signing in Xcode

1. Open `ios/BodyCompass/BodyCompass.xcodeproj`.
2. Select the **BodyCompass** project, then the **BodyCompass** target.
3. Open **Signing & Capabilities**, enable automatic signing, and choose your Apple Developer team.
4. Repeat for **BodyCompass Watch App**.
5. Confirm the bundle identifiers are unique for your developer account.

## 3. Validate the signed iPhone app

- Complete onboarding and edit the profile.
- Accept, partially accept, and deny Apple Health permissions; confirm manual entry still works.
- Confirm weight, body fat, steps, active energy, sleep, workouts, and resting heart rate populate when shared.
- Capture a meal with the camera and choose one from Photos.
- Complete and delete a weekly three-angle progress check-in.
- Enable a schedule reminder and confirm it arrives.
- Stop the local server, confirm the app says local data remains safe, restart it, and tap **Retry**.
- Export data and test both server-data and device-data deletion on disposable beta data.

## 4. Validate Apple Watch Series 10

Follow `docs/apple-watch-setup.md`, then verify:

- The latest routine reaches the Watch and remains available with the iPhone disconnected.
- Strength and swim handoffs open Apple's Workout app through WorkoutKit.
- A completed Apple workout is imported into the intended BodyCompass session.
- Manual set and swim logs survive a disconnect and merge once after reconnecting.
- Pool and open-water choices both hand off correctly; Apple Workout owns pool-length and sensor handling.

## 5. Validate live AI providers

Use server-side environment variables only. Never add API keys to Xcode, Swift source, or Git.

- Analyze one clear meal and one intentionally poor image.
- Confirm the app still returns a combined result when either OpenAI or Gemini fails.
- Run one Coach conversation and review a proposed routine change before confirming it.
- Analyze a standardized progress check-in and verify the estimate is presented as a broad, non-medical range.

## 6. Run a seven-day personal beta

Each day, use Health sync, schedule completion, training, meals, and Coach. During the week, check for crashes, lost entries, duplicate Watch logs, incorrect day rollover, unreadable text at larger Dynamic Type sizes, and confusing offline states. At week end, complete the review and photo check-in.

Record every release-blocking problem as a GitHub issue. Phase 9 is complete only after the seven-day run has no unresolved critical issue.

## 7. Prepare TestFlight

1. Increment the build number in Xcode for every upload.
2. Choose a generic iOS device, then **Product > Archive**.
3. In Organizer, validate and distribute to App Store Connect.
4. Complete App Store privacy answers for health, fitness, photos, and user content based on the shipped behavior.
5. Add yourself as an internal tester first.
6. Verify install, launch, Health permissions, Watch installation, and deletion from the TestFlight build before inviting anyone else.

## Release gates

- [ ] Automated preflight passes.
- [ ] Signed iPhone checks pass.
- [ ] Series 10 checks pass.
- [ ] Live OpenAI and Gemini checks pass.
- [ ] Seven-day personal beta passes without a critical issue.
- [ ] Privacy answers and support contact are complete in App Store Connect.
- [ ] Internal TestFlight build passes a clean-install smoke test.
