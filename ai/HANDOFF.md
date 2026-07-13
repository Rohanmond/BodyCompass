# BodyCompass Model Handoff

Last audited: July 13, 2026

Use this file as the authoritative starting point for Claude, ChatGPT, Gemini, Codex, or another coding model. Read the linked product and engineering documents before changing code.

## Repository State

- Repository: `Rohanmond/BodyCompass`
- Primary branch: `main`
- Primary implementation state: Phases 0-4 complete; Phase 4W Apple Workout handoff and basic result import simulator-build verified
- iOS deployment target: iOS 17
- App: native SwiftUI under `ios/BodyCompass`
- Shared logic: Swift package target `BodyCompassCore`
- Backend: dependency-light Node 20 API under `server`
- Persistence today: `UserDefaults` on iOS and in-memory backend state only
- AI today: mock OpenAI and Gemini provider functions; no real provider HTTP calls

Local generated files may appear as `ios/BodyCompass/.swiftpm/` and `server/pnpm-lock.yaml`. Do not stage, delete, or redesign package management around them unless the user explicitly requests it. The documented backend workflow uses npm.

## Verified Baseline

The following passed during the July 13, 2026 audit:

- `swift run BodyCompassCoreCheck`
- `npm test` with 3 passing backend tests
- Xcode iOS Simulator build with `CODE_SIGNING_ALLOWED=NO`

This verifies compilation and existing automated checks. It does not verify real Apple Health data, notification delivery, camera behavior, or device signing.

## Implemented

### Foundation and iOS App

- Working Xcode project and shared `BodyCompass` scheme.
- Five tabs: Today, Meals, Goal, History, and Coach.
- First-run onboarding and profile editing.
- Local profile persistence with Codable JSON in `UserDefaults`.
- 12% body-fat projection with aggressive, optimum, and conservative timelines.

### Health and Daily Accountability

- HealthKit authorization-request flow.
- Independent queries for steps, active energy, workouts, sleep, weight, body fat, and resting heart rate.
- Pull-to-refresh and refresh-on-open behavior.
- Persistent daily manual overrides for weight, body fat, and sleep.
- Editable generic daily task schedule with categories, completion, reorder, and reminder times.
- Daily and rolling seven-day adherence calculations.
- Metric-aware next-best-action logic.
- Local notification scheduling implementation.

### Backend Scaffold

- Routes for health, goal projection, meal analysis, chat, and health snapshots.
- Goal projection tests.
- Mock dual-provider meal and chat responses.

### Phase 4: Structured Training

The generic daily task schedule and the weekly strength/swimming program are both implemented and simulator-build verified.

- Pure models in `Sources/BodyCompassCore/TrainingRoutine.swift`, `TrainingSeed.swift`, and `TrainingLogs.swift`: routines, days, sessions, prescriptions, set/swim logs, one-day exceptions, versions, validation, day-level diffing, edit-review warnings, proposals, and a deterministic conservative double-progression advisor. All covered by `BodyCompassCoreCheck`.
- The exact starting split is seeded and survives relaunch (Mon chest+triceps, Tue back+biceps then swimming, Wed legs, Thu swimming, Fri upper body, Sat arms then swimming, Sun swimming).
- A setup questionnaire (experience, equipment, limitations, swim duration/intensity) gates detailed prescription generation; no starting weights are ever invented.
- `App/TrainingStore.swift` owns persistence (UserDefaults) for versions, setup, exceptions, logs, and the pending proposal.
- Screens: `TrainingWeekView` (week, history, rollback, proposal entry), `TrainingSessionView` (today's prescriptions, progression hints, set/swim logging, rest-day exceptions), `TrainingEditorViews` (setup questionnaire, day editor, exercise editor with substitution swapping), `RoutineProposalView` (before/after diff, Confirm/Edit/Reject, staleness handling). Today tab links to session and week.
- Manual edits validate, warn on material volume increases or losing the only rest day, and activate directly as a new version. Coach proposals stay pending until explicit confirmation; a proposal built against an older version is stale and cannot be applied; proposals are refused entirely when setup context is missing.

Remaining Phase 4 niceties (deferred): date-range pauses, one-tap move/copy between days, and UI for non-rest one-day exceptions (the core `TrainingDayException` already supports arbitrary replacement sessions).

### Phase 4W: Apple Watch and Apple Workout

- Device baseline: Apple Watch Series 10 on watchOS 26.1 paired with iPhone on iOS 26.5.
- The iPhone target embeds a `BodyCompass Watch App` target with a shared scheme and shared training DTO/WorkoutKit plan source membership.
- `PhoneWatchSyncService` sends the active routine via application context, receives queued Watch logs, merges them through `TrainingStore`, and acknowledges their stable UUIDs.
- `WatchRoutineStore` persists the latest routine and pending strength/swim logs so today's plan and completed logs survive disconnects and relaunches.
- Confirmed product rule: Apple Workout always owns active strength and swimming workouts. BodyCompass never starts a parallel `HKWorkoutSession`.
- `WorkoutPlanFactory` maps strength and swimming sessions to stable-ID WorkoutKit plans. Strength uses structured custom steps when runtime-supported and otherwise falls back to open Traditional Strength Training. Swimming asks Pool/Open Water per handoff; Apple owns pool length.
- iPhone `WorkoutKitService` requests scheduling authorization, schedules plans, and matches completed HealthKit workouts by plan/session UUID to show duration, energy, and swimming distance.
- Watch `WatchWorkoutLauncher` opens plans in Apple Workout. The companion still provides previous-performance prefilling, substitutions, load/reps/RIR, pain severity, rest timers, optional haptics, and durable offline manual logs.
- Recent iPhone strength history is included in application context. Watch keeps acknowledged history separate from pending delivery, preserving stable set numbers and prior values through reconnects.
- The Apple Workout migration compiles for iOS and generic watchOS Simulator SDKs. No claim of physical WorkoutKit scheduling/opening, HealthKit result matching, connectivity, or signing verification has been made.

## Partially Implemented

### Phase 5: Meals

- Meal UI, notes field, analysis model, endpoint, and mock providers exist.
- Camera/photo picker, upload, typed API client, real providers, correction persistence, and history do not exist.

### Phase 6: Coach

- UI tabs and mock backend endpoint exist.
- Real chat transport, profile/health/meal/training context, conversation persistence, safety classification, and structured routine proposals do not exist.

### Phase 7: History and Weekly Photos

- History placeholder exists.
- Charts, weekly review, standardized front/side/back capture, private upload, visual comparison, and dual-AI body-fat range analysis do not exist.

Photo body-fat output must be a non-clinical range with confidence and limitations, never an exact measurement.

## Not Implemented

- Remaining Phase 4W: physical WorkoutKit/HealthKit validation and recovery-aware suggestions. See `docs/apple-watch-plan.md`.
- Real OpenAI and Gemini API calls.
- Typed iOS backend client.
- Database, authentication, or private object storage.
- Export and complete deletion controls.
- TestFlight/App Store preparation.
- Real-device HealthKit and notification verification.

## Recommended Next Work

The user explicitly chose Apple Workout ownership for both strength and swimming. Validate that path next:

1. Follow `docs/apple-watch-setup.md` on the paired Series 10 and iPhone.
2. Verify WorkoutKit authorization, iPhone scheduling, Watch `openInWorkoutApp()`, structured-strength support/fallback, and Pool/Open Water handoff.
3. Complete workouts in Apple Workout and verify UUID-linked duration, energy, and swimming distance import.
4. Verify reconnect delivery and UUID deduplication for separate BodyCompass set logs.
5. Fix device-only signing or connectivity issues without reintroducing a custom active workout session.

Phase 6 (Coach) should reuse the existing `RoutineChangeProposal` confirmation contract when providers start generating routine changes — the Confirm/Edit/Reject flow and staleness handling are already built.

After the Watch slice, Phase 5 meal capture remains the next non-Watch milestone. The detailed Watch plan is `docs/apple-watch-plan.md`.

Keep the generic daily task schedule and structured training routine separate. The former tracks habits (`AppStore`); the latter owns programming, performance, and progression (`TrainingStore`).

## Completion Criteria for Structured Training

All met in the July 13, 2026 implementation:

- The seeded split survives app relaunch (persisted routine versions).
- User can view exactly what to do today (`TrainingSessionView` from Today).
- Strength prescriptions include sets, rep ranges, effort, rest, and substitutions.
- User can log load, reps, and effort; swimming supports duration, distance, and intensity.
- Manual edits create a new version and can be rolled back (restore copies forward).
- A one-day exception does not mutate the repeating routine.
- Progression suggestions are deterministic and tested in `BodyCompassCoreCheck`.
- Coach cannot activate a proposal without confirmation; stale proposals cannot apply.
- Invalid routines produce validation alerts; missing-setup proposals are refused with an explanation.
- Swift check, backend tests, and Xcode Simulator build pass.

## Non-Negotiable Product Rules

- API keys remain backend-only.
- Call both OpenAI and Gemini for real meal, coach, and progress-photo analysis unless the product plan is explicitly changed.
- Preserve raw provider outputs and show a reconciled result.
- Never silently apply an AI routine change.
- Do not guess fixed workout loads without performance history.
- Protect sensitive progress photos: metadata removal, private storage, deletion, and no public URLs.
- Do not diagnose conditions or reinforce extreme deficits, unsafe training, or eating-disorder behavior.
- The user is learning Swift; keep setup and code explanations beginner-friendly.

## Engineering Notes

- `BodyCompassCore` must remain UI-, HealthKit-, notification-, and network-free.
- Some core Swift files are compiled by both Swift Package Manager and the Xcode app target.
- New Swift files must be added to `BodyCompass.xcodeproj/project.pbxproj`; merely creating a file does not attach it to the app target.
- The Xcode project is currently maintained manually. Preserve existing groups and target membership.
- Use conditional `canImport(BodyCompassCore)` imports where the current dual-build pattern requires them.
- Keep API keys out of iOS source, plist files, logs, fixtures, and commits.
- Do not claim HealthKit or notifications are device-verified until tested on a signed iPhone.

## Required Reading

1. `docs/prd.md`
2. `docs/phases.md`
3. `docs/training-plan.md`
4. `docs/apple-watch-plan.md`
5. `ai/architecture.md`
6. `ai/data-model.md`
7. `ai/api-contract.md`
8. `ai/coding-guidelines.md`
9. `ai/commands.md`
