# BodyCompass Model Handoff

Last audited: July 13, 2026

Use this file as the authoritative starting point for Claude, ChatGPT, Gemini, Codex, or another coding model. Read the linked product and engineering documents before changing code.

## Repository State

- Repository: `Rohanmond/BodyCompass`
- Primary branch: `main`
- Primary implementation state: Phases 0-8 complete; Phase 9 code-side polish and signed iPhone launch verified; Phase 9B is in progress and the physical Watch gate is deferred
- iOS deployment target: iOS 17
- App: native SwiftUI under `ios/BodyCompass`
- Shared logic: Swift package target `BodyCompassCore`
- Backend: dependency-light Node 22.5+ API under `server`
- Persistence today: local-first iOS storage plus SQLite and encrypted private server image storage
- AI today: real OpenAI and Gemini meal, progress-photo, and contextual Coach adapters with no-key mock fallback

Local generated files may appear as `ios/BodyCompass/.swiftpm/` and `server/pnpm-lock.yaml`. Do not stage, delete, or redesign package management around them unless the user explicitly requests it. The documented backend workflow uses npm.

## Verified Baseline

The following passed during the July 13, 2026 audit:

- `swift run BodyCompassCoreCheck`
- `npm test` with 26 passing backend tests
- Xcode iOS and watchOS Simulator builds with `CODE_SIGNING_ALLOWED=NO`
- Phase 9 release metadata/icon validation and the updated iPhone and standalone Watch simulator builds
- W5 ready/recover/caution core scenarios and the updated iPhone plus standalone Watch builds

On July 14, 2026, Xcode automatic signing created a valid Personal Team development certificate and iPhone/Watch provisioning profiles. A fresh signed build completed, and BodyCompass installed and launched successfully on the user's physical iPhone 17 Pro running iOS 26.5. The paired Series 10 remained undiscoverable as an Xcode watchOS destination, and the user chose to continue iPhone validation while deferring that release gate.

This verifies compilation and existing automated checks. A later July 14 signed-iPhone run also verified device signing, full-permission Apple Health reads, authenticated private backup, and local notification delivery. Physical camera, partial/denied Health access, and Watch behavior remain unverified.

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
- Real dual-provider meal vision and contextual Coach adapters with mock fallback.

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
- iPhone `WorkoutKitService` requests scheduling authorization, schedules plans, and matches completed HealthKit workouts by plan/session UUID to show duration, energy, swimming distance, average heart rate, and an optional one-minute recovery drop.
- Watch `WatchWorkoutLauncher` opens plans in Apple Workout. The companion still provides previous-performance prefilling, substitutions, load/reps/RIR, pain severity, rest timers, optional haptics, and durable offline manual logs.
- Recent iPhone strength history is included in application context. Watch keeps acknowledged history separate from pending delivery, preserving stable set numbers and prior values through reconnects.
- The Apple Workout migration compiles for iOS and generic watchOS Simulator SDKs. No claim of physical WorkoutKit scheduling/opening, HealthKit result matching, connectivity, or signing verification has been made.
- W5 persists session RPE/soreness and uses the tested deterministic `RecoveryAdvisor` to combine completion, RIR, pain, sleep, resting-heart-rate deviation, recent volume, and optional heart-rate recovery into a reasoned next-session action. It never edits the routine or prescribes load from heart rate alone.

### Phase 5: Meals

- Camera and Photos picker inputs re-render selected images at a bounded size, which normalizes orientation and strips original metadata before JPEG upload.
- `MealAPIClient` sends the image, notes, and protein target to the backend. The server caps JSON at 12 MB and decoded images at 8 MB.
- OpenAI Responses and Gemini generateContent adapters request structured estimates. Missing keys produce deterministic mock estimates; one-provider failure still yields a lower-confidence reconciliation.
- The app shows Combined, ChatGPT, and Gemini results, supports calorie/macro correction, and stores accepted meals in `UserDefaults` with protected photos in private Application Support storage.
- Deleting a meal deletes both its metadata and local image. Physical-camera and live-provider-key checks remain unverified.

### Phase 6: Coach

- `CoachAPIClient` sends bounded profile, HealthKit/manual snapshot, accepted meals, schedule/adherence, goal projection, training setup/routine, and recent workout logs. Meal image bytes are never included.
- `CoachHistoryStore` persists the latest 50 exchanges locally. Combined, ChatGPT, and Gemini tabs preserve provider modes and errors.
- OpenAI and Gemini return structured answers, one next action, safety notices, and optional bounded routine instructions. Missing keys use complete deterministic mocks; one provider may fail without losing the combined answer.
- Deterministic server classification covers urgent medical symptoms, injury, extreme deficits, eating-disorder reinforcement, and drug advice. Unsafe answers cannot carry routine changes.
- `TrainingStore.createProposal(from:)` only accepts known day/session/exercise targets and a small operation set, validates the resulting week, and creates a pending `RoutineChangeProposal`. Confirm/Edit/Reject, staleness, versioning, and rollback remain unchanged.
- The old Training-screen mock proposal button is removed. Live-key validation remains pending.

### Phase 7: History and Weekly Photos

- `AppStore` persists up to 180 daily HealthKit/manual snapshots and derives a trend-aware weekly goal projection.
- History uses native Charts for weight and body fat plus seven-day adherence, protein, strength, and swimming summaries.
- The weekly check-in requires front/side/back images and explicit morning, lighting/distance, and full-body confirmations.
- Images are resized and re-rendered before upload; accepted JPEGs use complete file protection in private Application Support storage.
- The backend validates bounded images and calls OpenAI and Gemini vision adapters, with deterministic mocks and one-provider fallback.
- Results remain broad non-clinical ranges with quality, visible changes, limitations, suggestions, and one next-week action.
- The user can correct or reject an estimate, compare with the prior check-in, and delete the saved photos and record.
- Physical-camera and live-provider verification remain pending.

Photo body-fat output must be a non-clinical range with confidence and limitations, never an exact measurement.

### Phase 8: Persistence and Private Account

- `BodyCompassStore` uses Node's SQLite API with WAL, foreign keys, per-user records, and idempotent device synchronization.
- Tables cover users, profiles, health snapshots, schedules, accepted meals, Coach exchanges, progress check-ins, and progress-photo references.
- Meal/progress bytes are AES-256-GCM encrypted in a non-public file vault with random references and deletion/replacement cleanup.
- Local development permits one private owner without a token. Configuring `BODYCOMPASS_API_TOKEN` requires constant-time bearer authentication; production also requires `BODYCOMPASS_STORAGE_SECRET`.
- `AccountAPIClient` keeps device saves local-first and backs up profile, schedule, health, meals, and progress check-ins. Its bearer token lives in Keychain.
- Goal → Data & Privacy shows backup state, configures the token, exports JSON with optional image contents, and deletes server plus local app data. Apple Health is never deleted.
- SQLite restart, encrypted export, idempotency, auth, deletion, iOS/Watch compilation, and authenticated HTTP routes are verified. Production HTTPS and backup/restore remain operational work.

### Phase 9: Polish and Beta Preparation

- iPhone and Watch targets have production 1024-pixel app icons and privacy manifests.
- The app root supplies a keyboard Done action plus scroll/outside-tap dismissal to every text-entry flow.
- Today is priority-first with distinct health-metric colors and explicit time windows; Goal has a visual 12% summary and scannable pacing rows; Meals and Coach use the refreshed grouped visual system.
- Today distinguishes private-backup failure from local data loss and offers a retry action.
- Dashboard metrics, adherence, schedule rows, progress-photo selection, and charts have VoiceOver summaries.
- History charts use readable padded scales; body fat includes the 12% target reference.
- `scripts/release-preflight.sh --build` validates metadata/icons, runs backend and core checks, and builds both simulator targets.
- `docs/beta-checklist.md` is the authoritative signed-device, Series 10, live-provider, seven-day, and TestFlight checklist.

## Not Implemented

- Remaining Phase 4W: physical WorkoutKit/HealthKit, reconnect, and recovery-sample validation. See `docs/apple-watch-plan.md`.
- Additional typed iOS clients beyond meals, Coach, progress analysis, and account backup.
- A completed internal TestFlight upload and clean-install smoke test.
- Partial/denied real-device HealthKit verification; the signed full-permission path and local notification delivery are verified.

## Recommended Next Work

Run the Phase 9 beta gates next:

1. Complete Phase 9C live AI and physical-camera validation.
2. Return to partial/denied HealthKit checks and the deferred Phase 9A/9B physical Watch discovery and Apple Workout validation using `docs/apple-watch-setup.md` before release.
3. Complete Phase 9D HTTPS deployment and a backup/restore drill.
4. Complete the Phase 9E seven-day personal beta.
5. Complete the Phase 9F internal TestFlight clean-install smoke test.

The detailed status, requirements, and completion criteria for Phase 9A-9F are in `docs/phases.md`. Run `./scripts/release-preflight.sh --build` before device testing and again before archiving.

Phase 6 Coach instructions now reuse the existing `RoutineChangeProposal` confirmation contract; preserve Confirm/Edit/Reject and staleness handling in future changes.

The detailed Watch plan remains `docs/apple-watch-plan.md` for paired-device validation, and Phase 8 deployment still needs HTTPS plus a backup/restore drill.

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
