# Apple Watch Workout Companion Plan

## Product Goal

Make BodyCompass useful while the user is actively lifting or swimming without requiring constant iPhone interaction. Apple Watch should show the current prescription, capture live workout data, provide discreet haptics, log performance, and sync the completed session back to the existing training system.

Status: in progress. W1 is implemented and simulator-build verified. The strength core of W2 is implemented; real-device validation and the remaining W2 controls are pending.

## Recommended Architecture

Use a BodyCompass watchOS companion app for strength sessions and BodyCompass-specific logging. Run active sessions with HealthKit workout sessions and a live workout builder so watchOS can collect workout data and keep the experience active during the session.

Use WorkoutKit where it fits, especially for scheduling compatible swimming or interval plans into Apple's Workout app. Use Watch Connectivity for durable routine/log synchronization and offline delivery. Use HealthKit workout mirroring for an active BodyCompass workout that needs live iPhone controls and metrics.

The Watch must remain usable when the iPhone is unavailable. Queue logs locally and reconcile them when connectivity returns.

## Watch Strength Experience

The active strength screen should show only what is needed in motion:

- current exercise and set number,
- target rep range and RIR/RPE,
- previous performance for context,
- rest timer,
- current heart rate, elapsed time, and active energy,
- large Complete Set, Skip, Substitute, Pause, and End controls.

After a set, the user can confirm reps, load, and effort. Use the Digital Crown or simple steppers for quick numeric editing. Play optional haptics when rest is nearly complete and complete.

Do not depend on automatic exercise or rep recognition for the MVP. Logged reps and load remain user-confirmed. Do not change working weight from heart rate alone.

## Watch Swimming Experience

For swimming days:

- show pool or open-water mode,
- show planned duration, distance, or interval structure,
- show elapsed time, distance/laps when available, heart rate when available, and active energy,
- use restrained haptics for interval transitions,
- clearly explain that water can interrupt heart-rate readings,
- import the completed HealthKit workout into the BodyCompass training log.

WorkoutKit should be evaluated first for scheduling compatible swim/interval plans into Apple's Workout app. A custom BodyCompass workout session is appropriate when BodyCompass needs its own live screens or set/session controls.

## Live iPhone and Watch Behavior

When both apps are active:

- starting on either supported device starts or opens the Watch workout,
- pause, resume, and end state stay synchronized,
- iPhone shows a larger mirrored workout dashboard,
- iPhone can send Skip, Substitute, Extend Rest, and session-note actions,
- Watch set/swim logs appear on iPhone with conflict-safe identifiers,
- a disconnect never discards a completed set or workout.

Use HealthKit workout mirroring for the workout lifecycle and live workout data. Use Watch Connectivity for routine versions, setup context, pending logs, and background/offline synchronization.

## Coaching Rules During a Workout

Live guidance should be short and actionable:

- rest timer reminders,
- current target reps and effort,
- a prompt to extend rest after user-reported high effort,
- a caution prompt after pain is reported,
- swimming pace/interval guidance when supported,
- optional hydration or session-duration reminders.

The app may propose a lighter set, substitution, longer rest, or ending the session, but the user must confirm. It must not diagnose symptoms or use heart rate alone to prescribe strength load changes. Chest pain, fainting, severe shortness of breath, or other urgent warning signs should stop coaching and direct the user toward appropriate help.

## Post-Workout Update

After saving, merge:

- HealthKit workout duration, heart-rate summary, active energy, and available distance/lap data,
- completed strength sets, reps, load, and RIR/RPE,
- swimming duration, distance, and intensity,
- skipped/substituted exercises,
- session RPE, pain/limitation notes, and completion percentage.

Then update adherence and progression suggestions. Routine changes remain proposals and still require confirmation.

## Delivery Milestones

### W1: Watch Target and Sync Foundation

Status: implemented and simulator-build verified; paired-device validation pending.

- Add a watchOS companion target and shared training DTOs.
- Configure signing, HealthKit permissions, companion identifiers, and capabilities.
- Sync active routine and today's session to Watch.
- Persist a local Watch cache and queued logs.

### W2: Strength Workout MVP

Status: partially implemented. HealthKit start/pause/resume/end, live heart rate and active energy, quick load/reps/RIR logging, rest countdowns, and haptics compile. Elapsed-time presentation, substitutions, pain notes, a haptic setting, and physical-device validation remain.

- Start, pause, resume, and end a HealthKit workout session.
- Show current exercise, prescription, heart rate, time, and energy.
- Log sets, reps, load, effort, substitutions, and pain notes.
- Add rest timer and optional haptics.

### W3: Swimming and WorkoutKit

Status: not started. The Watch currently supports durable manual swim logging only.

- Map compatible swim plans to WorkoutKit.
- Sync or open scheduled workouts in Apple's Workout app where supported.
- Import completed swimming workout metrics into BodyCompass.
- Add BodyCompass custom swim UI only for requirements WorkoutKit cannot cover.

### W4: Mirrored iPhone Experience

Status: not started.

- Mirror active session state and metrics to iPhone.
- Add bidirectional pause, resume, end, and session actions.
- Reconcile offline logs without duplication.

### W5: Recovery-Aware Suggestions

Status: not started.

- Combine completed sets, RIR/RPE, heart-rate recovery context, sleep, soreness, and recent volume.
- Show a post-workout recommendation and next-session progression proposal.
- Keep every material training-plan change behind confirmation.

## Acceptance Criteria

- Today's routine reaches Watch and remains available without iPhone connectivity.
- A strength workout can be completed and saved from Watch.
- Set logs sync exactly once and survive disconnect/reconnect.
- Rest haptics can be disabled.
- A swim workout imports available HealthKit metrics without treating missing heart rate as failure.
- iPhone and Watch agree on workout lifecycle state during mirrored sessions.
- No live data or AI suggestion silently changes the active routine.
- Real-device tests pass on the user's paired iPhone and Apple Watch.

## Confirmed Device Information

- Apple Watch Series 10,
- watchOS 26.1,
- iPhone iOS 26.5.

## Information Still Needed for W3

- pool versus open-water swimming,
- preferred pool length,
- whether BodyCompass should run the workout itself or primarily schedule into Apple's Workout app.

Framework availability must be checked against those OS versions before choosing deployment targets.

Beginner setup and paired-device test steps: `docs/apple-watch-setup.md`.

## Official Apple References

- HealthKit workout sessions: https://developer.apple.com/documentation/healthkit/running-workout-sessions
- Multidevice workout mirroring: https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app
- WorkoutKit: https://developer.apple.com/documentation/workoutkit
- Watch Connectivity: https://developer.apple.com/documentation/watchconnectivity
- Workout design guidance: https://developer.apple.com/design/human-interface-guidelines/workouts
