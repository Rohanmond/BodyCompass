# Apple Watch Workout Companion Plan

## Product Goal

Make BodyCompass useful for planning, launching, and reviewing lifting and swimming while Apple Workout owns every active workout and sensor stream.

Status: in progress. WorkoutKit handoff for strength/swimming and basic HealthKit result import are implemented and simulator-build verified. Real-device validation and recovery-aware coaching remain.

## Recommended Architecture

Apple Workout is the only active workout owner for both strength and swimming. BodyCompass creates a WorkoutKit plan, schedules it from iPhone or opens it from Watch, then imports the completed HealthKit workout using the BodyCompass session UUID stored as the WorkoutPlan ID.

Use Watch Connectivity only for BodyCompass routine context and manual set/swim details. BodyCompass does not start a parallel `HKWorkoutSession` and does not mirror Apple Workout's lifecycle.

The Watch must remain usable when the iPhone is unavailable. Queue logs locally and reconcile them when connectivity returns.

## Watch Strength Experience

The Apple Workout plan should show the supported workout steps and native metrics. The BodyCompass Watch companion retains:

- current exercise and set number,
- target rep range and RIR/RPE,
- previous performance for context,
- rest timer,
- substitutions, pain severity, and rest haptics,
- manual set/load/reps/RIR confirmation when needed.

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

The user chooses Pool or Open Water when sending the plan. Apple Workout owns pool length, Water Lock, laps, distance, heart rate, energy, and workout controls.

## Live iPhone and Watch Behavior

The iPhone schedules plans through `WorkoutScheduler`; the Watch companion opens a plan through `openInWorkoutApp()`. Apple Workout owns start, pause, resume, end, and native metrics. BodyCompass imports completed results and reconciles manual logs by UUID.

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

Status: superseded by the confirmed Apple Workout-only decision. The manual strength logging work remains; the custom BodyCompass `HKWorkoutSession` lifecycle has been removed.

- Open a BodyCompass strength plan in Apple Workout.
- Let Apple Workout own heart rate, time, energy, and lifecycle controls.
- Log sets, reps, load, effort, substitutions, and pain notes.
- Add rest timer and optional haptics.

### W3: Apple Workout and WorkoutKit Handoff

Status: implemented and simulator-build verified; paired-device validation pending.

- Map strength and swim sessions to stable-ID WorkoutKit plans.
- Use structured strength steps when WorkoutKit reports support; otherwise fall back to open Traditional Strength Training.
- Schedule plans from iPhone and open them from the Watch companion.
- Choose Pool or Open Water per swim; leave pool length to Apple Workout.

### W4: Completed Workout Import

Status: basic implementation complete and simulator-build verified; paired-device validation pending.

- Match completed HealthKit workouts to BodyCompass sessions by WorkoutPlan UUID.
- Import duration, active energy, and swimming distance when available.
- Keep BodyCompass set/load/reps/RIR logs separate and reconcile without duplication.

### W5: Recovery-Aware Suggestions

Status: not started.

- Combine completed sets, RIR/RPE, heart-rate recovery context, sleep, soreness, and recent volume.
- Show a post-workout recommendation and next-session progression proposal.
- Keep every material training-plan change behind confirmation.

## Acceptance Criteria

- Today's routine reaches Watch and remains available without iPhone connectivity.
- A strength or swim plan opens in Apple Workout without starting a parallel BodyCompass workout.
- Set logs sync exactly once and survive disconnect/reconnect.
- Rest haptics can be disabled.
- A swim workout imports available HealthKit metrics without treating missing heart rate as failure.
- A completed Apple workout maps back to the correct BodyCompass session UUID.
- No live data or AI suggestion silently changes the active routine.
- Real-device tests pass on the user's paired iPhone and Apple Watch.

## Confirmed Device Information

- Apple Watch Series 10,
- watchOS 26.1,
- iPhone iOS 26.5.

## Confirmed Workout Ownership

- Apple Workout always owns strength and swimming workouts.
- BodyCompass uses WorkoutKit for planning/scheduling/opening and HealthKit for completed metrics.
- Pool/Open Water is selected for each swim. Apple Workout owns pool length.

Framework availability must be checked against those OS versions before choosing deployment targets.

Beginner setup and paired-device test steps: `docs/apple-watch-setup.md`.

## Official Apple References

- WorkoutKit: https://developer.apple.com/documentation/workoutkit
- Watch Connectivity: https://developer.apple.com/documentation/watchconnectivity
- Workout design guidance: https://developer.apple.com/design/human-interface-guidelines/workouts
