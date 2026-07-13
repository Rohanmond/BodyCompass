# Run BodyCompass on Apple Watch

This guide assumes an Apple Watch Series 10 on watchOS 26.1 paired with an iPhone on iOS 26.5.

## One-Time Xcode Setup

1. Open `ios/BodyCompass/BodyCompass.xcodeproj` in Xcode.
2. Click the blue BodyCompass project at the top of the left sidebar.
3. Select the **BodyCompass** target, open **Signing & Capabilities**, and choose your Apple Developer team.
4. Select the **BodyCompass Watch App** target and choose the same team.
5. Keep **Automatically manage signing** enabled for both targets.
6. If Xcode reports that a bundle identifier is unavailable, replace `com.rohanmondal.bodycompass` with a unique identifier and keep the Watch identifier as that value plus `.watchkitapp`. Update `WKCompanionAppBundleIdentifier` in `WatchApp/Info.plist` to match the iPhone identifier.

The HealthKit capability is already present in both app targets. API keys are not needed for this Watch phase.

## Install on the Paired Devices

1. Connect or wirelessly pair the iPhone with Xcode and unlock both devices.
2. In Xcode's top toolbar, choose the **BodyCompass Watch App** scheme.
3. Choose the paired Apple Watch Series 10 destination. It normally appears beneath the paired iPhone.
4. Press the Run button or `Cmd-R`.
5. Accept the developer-mode, trust, and Health access prompts if they appear.

Xcode installs the iPhone companion and Watch app together. The first device build can take several minutes.

## First Test

1. Open BodyCompass on iPhone and finish training setup so the weekly routine contains detailed exercises.
2. Open BodyCompass on Apple Watch. Today's routine should appear.
3. On iPhone, open a strength session and tap **Add to Apple Workout**; grant Workout scheduling permission.
4. On Watch, open BodyCompass, choose the strength session, and tap **Open in Apple Workout**.
5. Complete and end the workout in Apple's Workout app.
6. Reopen the iPhone session and confirm duration and energy appear under the matching session.
7. Log one BodyCompass test set and confirm it appears in today's training log.
8. Turn off Bluetooth or move the phone away, log another set on Watch, reconnect, and confirm it syncs once without duplication.

## What Works in This Build

- Today's strength/swim plan caches on Watch and remains visible offline.
- Strength and swimming plans schedule/open in Apple Workout through WorkoutKit.
- Apple Workout owns start, pause, resume, end, heart rate, energy, and swimming metrics.
- Load, reps, and RIR can be logged with rest countdowns and haptics.
- Previous performance syncs from iPhone and prefills the next working values.
- Substitutions, pain severity, and optional haptics are available in BodyCompass; Apple Workout supplies elapsed time and the workout summary.
- Strength and manual swim logs queue offline and sync idempotently to iPhone.

Recovery-aware suggestions are not implemented yet. WorkoutKit and completed-workout import still require paired-device validation.

## Troubleshooting

- **Watch is missing as a destination:** verify the Watch is paired to the selected iPhone, both devices are unlocked, Developer Mode is enabled, and Xcode has finished preparing them.
- **Signing error:** choose the same team for both targets and use unique matching bundle identifiers.
- **No detailed exercises:** complete the training setup questionnaire on iPhone, then reopen both apps so the latest routine context syncs.
- **No live heart rate:** verify Health permissions in iPhone Settings and wear the Watch snugly. Heart-rate availability can vary during workouts.
- **Queued count does not clear:** open the iPhone app after reconnecting; Watch Connectivity will deliver and acknowledge the durable log in the background.
