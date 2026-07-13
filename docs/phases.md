# BodyCompass Step-by-Step Phases

This roadmap is written so each phase produces something useful and testable. Do not jump to App Store or payments before the core coach loop works.

## Current Implementation Status

Quick summary: `docs/implementation-status.md`.

Implemented:

- Phase 0 is implemented as the initial repo foundation.
- Swift core goal projection check passes with `swift run BodyCompassCoreCheck`.
- Backend unit tests pass with `npm test`.
- Backend health and goal projection endpoints have been smoke tested locally.
- PRD, setup docs, HealthKit notes, API notes, and beginner Swift guide exist.
- Phase 1 Xcode project, shared scheme, Info.plist, entitlements, and asset catalog exist.
- Phase 1 iOS simulator build succeeds with Xcode.
- Phase 2 onboarding, profile persistence, profile editing, and live goal recalculation are implemented.
- Phase 3 HealthKit permission flow, real daily metric queries, manual fallback entries, and Today-screen refresh are implemented.

- Phase 4 structured training: seeded weekly split, setup questionnaire, exercise prescriptions, set/swim logging, deterministic progression, versioned manual editing with rollback, one-day rest exceptions, and a mock coach proposal Confirm/Edit/Reject flow.
- Phase 4W W1: watchOS target, HealthKit capability, routine cache, Watch Connectivity routine sync, and durable queued log sync.
- Phase 5 meal logging: camera/library capture, compressed transient upload, dual-provider analysis, correction, and photo-free result history.
- Phase 6 Coach Chat: contextual dual-provider answers, safety routing, local history, and validated confirmed-only routine proposals.
- Phase 7 weekly review: persisted health trends, native charts, weekly adherence/nutrition/training summaries, trend-aware goal projection, and standardized private progress-photo analysis.

Partially implemented:
- Phase 4W implementation is simulator-build verified, including WorkoutKit handoff, completed-workout import, and recovery-aware coaching; paired-device validation remains.
- Phase 4 extras still open: date-range session pauses, one-tap move/copy of a session to another day, and richer one-day exceptions in the UI (core model already supports arbitrary replacement sessions).
- Phase 5 live dual-provider API analysis and one-provider fallback are verified; physical-camera validation remains.
- Phase 6 live dual-provider API validation is complete; signed-device UI and routine-proposal validation remain.
- Phase 7 needs physical-camera and live-provider vision validation; its complete product flow is implemented.
- Phase 1 is signed-device verified on the user's iPhone; physical Watch setup remains deferred.

Not implemented yet:

- Phase 4W real-device WorkoutKit, HealthKit, reconnect, and recovery-sample validation.
- Production backend deployment and restore drill.
- Signed-device, seven-day beta, and TestFlight release gates.

## Phase 0: Foundation

Goal: make the repo understandable and runnable.

Deliverables:

- Repo structure: `ios/`, `server/`, `docs/`.
- SwiftUI app shell with tabs.
- Swift core goal projection logic.
- Node backend with mock AI providers.
- Beginner docs for Swift and setup.

Status: implemented.

Implemented in this phase:

- Root repo docs and `.gitignore`.
- Swift package at `ios/BodyCompass`.
- SwiftUI app source files for Today, Meals, Goal, History, and Coach tabs.
- Shared Swift design components and mock app state.
- HealthKit service wrapper with the intended read types.
- Swift body-fat goal projection logic.
- Swift command-line verification through `BodyCompassCoreCheck`.
- Node backend with routes for health, goal projection, meal analysis, chat, and health snapshots.
- Mock OpenAI + Gemini provider flow.
- Backend goal projection tests.
- PRD, phased roadmap, API notes, HealthKit notes, setup guide, and Swift beginner guide.

Done when:

- `swift run BodyCompassCoreCheck` passes.
- `npm test` passes.
- Backend `/health` and `/api/goal/projection` work locally.

Phase 0 done status: done.

## Phase 1: Real iOS Project

Goal: make the app open and run from Xcode on simulator/device.

Status: implemented and simulator-build verified.

Implemented in this phase:

- `BodyCompass.xcodeproj` exists.
- Shared `BodyCompass` scheme exists.
- Existing SwiftUI app files are attached to the app target.
- Bundle ID is set to `com.rohanmondal.bodycompass`.
- App Info.plist includes HealthKit, camera, and photo library usage descriptions.
- HealthKit entitlements file exists.
- Placeholder asset catalog exists.
- Xcode beginner guide exists at `docs/xcode-phase-1.md`.
- Simulator build succeeds with `xcodebuild` when full Xcode is selected.

Deliverables:

- Create proper Xcode iOS project or workspace.
- Attach existing SwiftUI files to the iOS app target.
- Configure bundle ID, signing, app icon placeholder, and deployment target.
- Enable HealthKit capability.
- Add Info usage descriptions for HealthKit and camera/photo access.

Local verification note:

- Terminal verification with `xcodebuild` requires the active developer directory to point to full Xcode, not Command Line Tools.
- Real-device runs still require your Apple signing team in Xcode.

Done when:

- App runs in iOS Simulator.
- App runs on a real iPhone.
- All five tabs render without crashing.

## Phase 2: Profile and Goal Setup

Goal: let the user enter real starting data.

Status: implemented and simulator-build verified.

Implemented in this phase:

- First-run onboarding for name, age, height, weight, current body fat, target body fat, and preferred workout time.
- Input validation prevents an empty name or a target body-fat value that is not below the current estimate.
- Profile persistence using Codable JSON in `UserDefaults`.
- Automatic goal projection recalculation whenever the profile changes.
- Profile editing from the Goal tab.
- Clear aggressive, optimum, and conservative timeline estimates.

Deliverables:

- Onboarding screens for age, height, weight, current body fat, target body fat, and schedule preference.
- Persist profile locally.
- Show the initial 12% projection.
- Add clear explanation of optimum, aggressive, and conservative timelines.

Done when:

- User can complete onboarding.
- Goal tab reflects entered data.
- User can edit profile values.

Phase 2 done status: done.

## Phase 3: HealthKit Daily Sync

Goal: connect BodyCompass to Apple Health data.

Status: implemented and signed-device verified for the full-permission path. Real weight, active energy, resting heart rate, and daily values synced on the user's iPhone; partial and denied permission paths remain to be exercised manually.

Implemented in this phase:

- Connect Apple Health banner on the Today screen with a one-tap permission request.
- Real daily queries for steps, active energy, workout minutes, and last night's sleep.
- Most-recent-sample queries with short look-back windows for weight, body-fat percentage, and resting heart rate.
- Independent per-metric queries so denied or partial permissions never break the rest of the dashboard.
- Manual fallback entry for weight, body fat, and sleep that overrides imported values and persists per day.
- Today screen refreshes HealthKit data on open and with pull-to-refresh.
- Weight and body-fat metric cards on the Today dashboard with manual-entry source labels.

Deliverables:

- HealthKit permission screen.
- Read daily steps, active energy, weight, body-fat percentage, sleep, workouts, and resting heart rate.
- Manual fallback fields when HealthKit data is missing.
- Refresh data when Today screen opens.

Done when:

- App handles denied, partial, and full HealthKit permissions.
- Today dashboard shows real or manual metrics.
- Missing values do not break goal calculations.

Phase 3 done status: implementation, signed-device permission sheet, and real-metric reads are verified. Partial/denied access behavior remains a release check; the independent-query and manual-fallback implementation already handles those states.

## Phase 4: Daily Schedule, Training Plan, and Adherence

Goal: make the app a daily accountability system.

Status: implemented and simulator-build verified. Daily schedule, adherence, and the structured weekly training program (seeded split, prescriptions, logging, progression, versions, rollback, one-day exceptions, and confirmed-only Coach proposals) are all built.

Implemented in this phase:

- Editable daily schedule with add, edit, delete, and reorder in a dedicated editor screen.
- Each task has a category (weigh-in, nutrition, training, steps, sleep, other) used for icons and next-best-action ranking.
- Tap-to-complete tracking on the Today screen, persisted per day in `UserDefaults`.
- Daily adherence score plus a rolling 7-day adherence average from persisted `DayAdherenceRecord` history.
- Automatic daily roll that clears completion at a new day while preserving the task list and prior scores.
- Next-best-action logic that ranks training, protein, steps, sleep, and remaining tasks using real metrics and meal protein.
- Optional local reminders (UserNotifications) with a master toggle and a per-task reminder time.
- Pure schedule/adherence/next-best-action logic in `BodyCompassCore`, exercised by `BodyCompassCoreCheck`.

Structured training implemented in this phase:

- Pure training models in `BodyCompassCore` (`TrainingRoutine.swift`, `TrainingSeed.swift`, `TrainingLogs.swift`): routines, days, sessions, prescriptions, logs, exceptions, versions, proposals, validation, diffing, and progression — all covered by `BodyCompassCoreCheck`.
- Seeded Monday-to-Sunday chest/triceps, back/biceps + swim, legs, swim, upper-body, arms + swim, swim split, persisted across relaunch.
- A setup questionnaire (experience, equipment, limitations, swim duration/intensity) that gates detailed prescriptions; the app never invents starting weights.
- Weekly routine screen (`TrainingWeekView`) and today's session screen (`TrainingSessionView`), reachable from the Today tab.
- Day editor with session rename/type/add/remove, exercise add/remove/reorder, and per-exercise sets, rep range, RIR, rest, warm-up, technique notes, and substitution swapping.
- Pre-save review warnings when an edit materially increases weekly volume or removes the only rest day; validation errors block invalid routines with clear messages.
- One-day rest exceptions that never mutate the repeating routine, with one-tap restore.
- Set-by-set strength logging (load, reps, RIR, pain notes) and swim logging (duration, distance, intensity).
- Deterministic conservative double progression: establish baseline → add reps → add load (2.5%, min 1 kg), with pain notes forcing a caution state.
- Routine versions with history and rollback (restores copy forward as a new version).
- Coach proposal flow with reasons, recovery impact, exact before/after diff, staleness detection, and Confirm/Edit/Reject. Nothing activates without explicit confirmation, and proposals are refused when setup context is missing.

Still open (deferred, not blockers):

- Date-range session pauses and one-tap move/copy of a session to another day.
- UI for one-day exceptions beyond "rest today" (the core model already supports arbitrary replacement sessions).
- Live-key validation of Coach-generated proposals.

Deliverables:

- Editable daily schedule.
- Completion tracking.
- Daily adherence score.
- Next best action logic based on meals, protein, steps, workout, sleep, and schedule.
- Optional local reminders.

Done when:

- User can check off daily tasks.
- Today screen explains the most important remaining action.
- Weekly adherence score can be calculated.
- User can see what exercises, sets, reps, effort, and rest to perform today.
- User can manually change the weekly schedule and restore an earlier version.
- Coach cannot modify the active routine until the user confirms the proposal.

Phase 4 done status: complete and simulator-build verified. Real-device local-notification permission and delivery are verified on the user's iPhone.

## Phase 4W: Apple Watch Workout Companion

Goal: bring the structured training plan onto Apple Watch for live strength and swimming sessions.

Status: implementation complete and simulator-build verified; real-device verification remains.

Implemented so far:

- Shared watchOS app target and scheme embedded in the iPhone app.
- HealthKit workout entitlement and workout-processing configuration.
- Latest-routine sync from iPhone, persistent Watch cache, and offline fallback routine.
- Durable strength/swim log queues with UUID-based merge and acknowledgement.
- Today's session browser with strength and swimming entries.
- WorkoutKit strength plans with structured steps when supported and open Traditional Strength Training fallback.
- WorkoutKit Pool/Open Water swim plans without a BodyCompass pool-length setting.
- iPhone schedule action and Watch `openInWorkoutApp()` handoff for both workout types.
- Apple Workout-only lifecycle; the custom BodyCompass `HKWorkoutSession` path has been removed.
- Completed Apple workout matching by session UUID with duration, energy, and swimming distance import.
- Best-effort average heart rate and one-minute recovery import from Apple Health.
- Persisted post-workout RPE/soreness reviews with deterministic recovery guidance using completed work, RIR, pain, sleep, resting-heart-rate deviation, and recent volume.
- Plain-language next-session action with no automatic routine or load changes.
- Quick load, reps, and RIR set logging with rest countdown and haptic feedback.
- Recent iPhone strength history sync, durable acknowledged history, stable set numbering, and previous-session load/reps/RIR prefilling.
- Exercise substitutions, pain-severity notes, and a haptic preference in the separate BodyCompass manual log.
- Manual offline strength/swim details remain available alongside Apple sensor data.

Still open:

- Paired Series 10/iPhone signing, permission, connectivity, and workout validation.
- Physical-device validation for signing, connectivity, reconnect delivery, and exact-once merge.
- Physical-device WorkoutKit authorization, scheduling/opening, Apple Workout plan support, and HealthKit result import.

Deliverables:

- watchOS companion target with HealthKit workout capabilities.
- Offline sync of today's routine and durable queued workout logs.
- Strength workout UI for prescriptions, set logging, rest timers, optional haptics, substitutions, and pain/effort notes.
- Apple Workout-owned heart rate, elapsed time, active energy, lifecycle, and swimming metrics.
- WorkoutKit scheduling/opening for strength and swimming.
- Import of completed swimming duration, distance/laps, energy, and available heart-rate data.
- Watch Connectivity for routine versions, setup context, logs, and offline/background synchronization.
- Recovery-aware post-workout suggestions without automatic load or routine changes.

Done when:

- A complete strength session can be run and saved from Watch.
- Today's plan works without an active iPhone connection.
- Logs survive disconnects and sync exactly once.
- Swimming succeeds even when water prevents heart-rate readings.
- Completed Apple workouts match the intended BodyCompass session.
- Real-device tests pass on the user's paired Watch and iPhone.

Detailed plan: `docs/apple-watch-plan.md`.
Beginner device setup: `docs/apple-watch-setup.md`.

## Phase 5: Meal Photo Logging

Goal: make meal logging fast and useful.

Status: implemented and simulator-build verified; live dual-provider API analysis and fallback are verified, while physical-camera validation remains.

Implemented so far:

- Meal Log screen exists.
- Portion notes field exists.
- Backend meal analysis endpoint exists.
- Camera and Photos picker capture with downscaled, re-encoded JPEG upload.
- Typed iOS meal API client with loading and error states.
- Backend uses real OpenAI Responses and Gemini generateContent vision calls when keys are configured, with deterministic mocks otherwise.
- Independent provider estimates, reconciliation, and one-provider fallback.
- Editable calories/macros before save.
- Local meal history with protected image files and deletion.

Deliverables:

- Physical-iPhone camera validation.
- Live OpenAI and Gemini key/model validation (complete for notes-only API analysis and fallback; image capture remains).
- Database-backed history moves to Phase 8; Phase 5 history is local to the device.

Done when:

- User can log a meal photo.
- App shows OpenAI, Gemini, and combined estimates.
- User can correct the final calories/macros.
- Corrected meal is saved to history.

All functional completion criteria are implemented. Device and live-provider checks remain release verification rather than missing product flow.

## Phase 6: Coach Chat

Goal: connect AI answers to the user’s real goal data.

Status: implemented and simulator-build verified; live OpenAI and Gemini API responses and reconciliation are verified.

Implemented so far:

- Coach tab exists.
- Combined, ChatGPT, and Gemini UI tabs exist.
- Backend chat endpoint exists.
- Typed iOS chat client with persisted local conversation history.
- Bounded profile, health, accepted-meal, schedule, adherence, goal, and training context.
- Real OpenAI and Gemini structured provider calls when keys are configured, with complete mock fallback.
- Combined answer with one next action and one-provider fallback.
- Deterministic safety classification for urgent medical, injury, extreme deficit, eating-disorder, and drug-advice requests.
- Structured routine instructions matched against the active routine and validated before becoming a pending proposal.

Deliverables:

- Chat UI with combined, ChatGPT, and Gemini tabs.
- Backend chat endpoint with user profile, latest health snapshot, meals, and schedule context.
- Safety rules for medical, injury, extreme deficit, and eating-disorder topics.
- Live OpenAI and Gemini key/model validation (complete at the API layer; signed-device UI confirmation remains in Phase 9C).

Done when:

- User can ask coaching questions.
- Both providers respond.
- Combined answer gives one practical recommendation.
- Any routine change remains pending until Confirm; invalid or unknown changes are rejected.

## Phase 7: Weekly Review and History

Goal: turn logs and standardized progress photos into progress decisions.

Status: implemented and simulator-build verified; live-provider and physical-camera validation pending.

Implemented so far:

- Daily HealthKit/manual snapshots persist locally for up to 180 days.
- Native Charts show weight and body-fat trends with useful empty states.
- Seven-day adherence, logged protein, strength-day, and swimming-day summaries use existing stores.
- The 12% projection recalculates from the latest body metrics and recent weight trend.
- Front, side, and back photos can be selected or captured after morning, lighting/distance, and full-body confirmations.
- Photos are resized and re-rendered as JPEG before upload, which strips source metadata.
- Capture photos are discarded after analysis; check-in history retains only result metadata and trends.
- The progress endpoint validates pose, type, base64, per-image size, total size, and capture confirmations.
- OpenAI Responses and Gemini generateContent vision adapters return broad structured ranges, quality, changes, limitations, suggestions, and one next-week action; mock fallback works without keys.
- Combined, ChatGPT, and Gemini tabs preserve independent failures. One provider can fail without losing the check-in.
- The user can edit the accepted range or reject the estimate before saving.
- Check-in detail compares the current three angles with the immediately previous check-in.

Deliverables:

- Weight trend view.
- Body-fat trend view.
- Meal adherence view.
- Workout and sleep consistency view.
- Weekly projection recalculation.
- Optional weekly morning photo check-in with front, side, and back guidance.
- Capture-quality checks for consistent pose, framing, distance, and lighting.
- Private progress-photo upload with metadata removal and deletion controls.
- Dual-provider visual analysis returning a body-fat range, confidence, visible trend, and limitations.
- Comparison with previous check-ins using weight and activity trends as additional context.
- User correction or rejection of the AI body-fat estimate.
- Plain-language review: what worked, what failed, what changes next.

Done when:

- User can see why the timeline changed.
- User can compare weekly saved ranges and health trends without retaining photos or implying false precision.
- Weekly review produces a next-week action plan.

Phase 7 done status: all functional completion criteria are implemented. Physical-camera and live-key checks remain release verification; server-backed photo persistence belongs to Phase 8.

## Phase 8: Backend Persistence and Accounts

Goal: stop relying on in-memory/mock data.

Status: implemented and simulator-build verified; production deployment and restore testing remain.

Deliverables:

- Database schema for users, profiles, snapshots, meals, schedule items, and chats.
- Basic auth or private single-user mode.
- Analysis-only photo handling with no image persistence.
- Delete/export data controls.

Implemented:

- SQLite schema for private users, profiles, daily health snapshots, schedules, accepted meals, Coach exchanges, and photo-free progress check-ins.
- WAL mode, foreign keys, per-user ownership, idempotent daily snapshot and device-record synchronization, and persistence across process restart.
- Private single-user mode for local development plus constant-time bearer-token authentication when configured.
- Analysis photos are never written to iOS history, backend persistence, backup, or export; startup cleanup purges legacy files and database references.
- Local-first iOS backup for profile, health, schedule, accepted meal results, and progress check-in results.
- Bearer token stored in iOS Keychain, never in `UserDefaults` or source code.
- JSON account export containing result metadata and no photo contents.
- Exact-confirmation server deletion and a Goal → Data & Privacy screen that deletes server and local BodyCompass records while leaving Apple Health untouched.
- Automated restart, no-photo persistence, export, idempotency, auth, and deletion tests plus authenticated HTTP smoke testing.

Done when:

- Data survives server restart.
- User can delete meal/check-in result records and health logs; photos never enter history.
- API keys remain server-side only.

Phase 8 done status: functional completion criteria are implemented. Cloud hosting, backup/restore operations, multi-user identity, and production HTTPS are deployment work, not claims made by this local MVP.

## Phase 9: Polish and Beta

Goal: make it reliable enough for daily use.

Status: implemented and simulator-build verified. Signed-device, seven-day personal beta, and TestFlight checks remain.

Implemented:

- Production app icons for the iPhone and Watch targets.
- iPhone and Watch privacy manifests plus release-version and encryption metadata.
- Clear local-first recovery messaging and one-tap retry when private server backup is offline.
- VoiceOver summaries for dashboard metrics, adherence, schedule completion, progress photos, and trend charts.
- Improved trend scaling and a visible 12% body-fat target reference.
- App-wide keyboard dismissal with an explicit Done control, interactive scroll dismissal, and outside-tap dismissal.
- Refreshed operational UI with a priority-first Today screen, distinct metric colors, explicit HealthKit time windows, adherence progress, a visual 12% goal summary, and clearer Meals and Coach surfaces.
- A repeatable release preflight for metadata, icons, backend tests, Swift core checks, and both simulator builds.
- Beginner-friendly signed-device, Series 10, live-provider, seven-day beta, and TestFlight checklist in `docs/beta-checklist.md`.

### Remaining Phase 9 Execution Stages

Complete these stages in order. They are release gates, not missing simulator implementation.

#### Phase 9A: Signed Device Setup

Status: partially complete. The Personal Team certificate, automatic provisioning, signed iPhone build, installation, trust, and launch are verified. Physical Watch discovery/install is deferred by user choice and remains an open release gate.

- Select the Apple Developer team for the BodyCompass iPhone and Watch targets.
- Confirm unique bundle identifiers and automatic signing.
- Install and launch BodyCompass on the signed iPhone and paired Apple Watch Series 10.

Done when both apps install, launch, and can request their required permissions without a signing or entitlement error.

#### Phase 9B: Apple Device Validation

Status: in progress. Signed-iPhone HealthKit, authenticated backup, and local-notification delivery are verified. Partial/denied HealthKit checks plus WorkoutKit, reconnect, and other Watch-specific checks remain deferred until Xcode discovers the paired Watch.

Signed-iPhone progress: real HealthKit reads, authenticated private backup, and the Debug-only 10-second local-notification banner/sound delivery test are verified.

- Validate full, partial, and denied HealthKit permission states and real health metrics.
- Validate local schedule notification permission and delivery.
- Validate WorkoutKit scheduling and handoff to Apple's Workout app for strength, pool swimming, and open-water swimming.
- Confirm completed workouts import into the intended BodyCompass session with available duration, energy, distance, heart-rate, and recovery context.
- Disconnect and reconnect the devices; confirm queued manual logs survive and merge exactly once.

Done when the signed iPhone and paired Watch pass `docs/apple-watch-setup.md` without data loss, duplicate logs, or a release-blocking Apple integration issue.

#### Phase 9C: Live AI and Camera Validation

Status: in progress. Live dual-provider meal and Coach API responses, reconciliation, and meal one-provider fallback are verified. Physical-camera and progress-photo vision flows remain.

- Configure OpenAI and Gemini credentials on the backend only.
- Verified OpenAI and Gemini live together for meal analysis and Coach Chat; temporary provider throttling is retried with bounded backoff.
- Test a clear meal photo, a poor-quality meal photo, corrections, deletion, and one-provider fallback.
- Test Coach Chat and confirm routine changes still require Confirm/Edit/Reject.
- Test a standardized front/side/back progress check-in, correction/rejection, comparison, and deletion.
- Confirm AI body-fat output remains a broad non-medical range with confidence and limitations.

Done when both providers, each single-provider fallback, and all physical-camera flows work without exposing API keys in the apps.

#### Phase 9D: Production Backend Deployment

Status: pending deployment and operations work.

- Deploy the Node backend behind HTTPS.
- Configure stable API and storage secrets outside source control.
- Attach durable storage for SQLite result metadata.
- Back up the production data volume and complete a restore drill.
- Verify authenticated iPhone backup, export, and deletion against the deployed service.

Done when the service survives a restart and a tested backup can restore the metadata database.

#### Phase 9E: Seven-Day Personal Beta

Status: pending completion of Phases 9A-9D.

- Use Health sync, schedules, meals, Coach, training, and Apple Watch workouts every day for seven days.
- Complete the weekly review and standardized progress-photo check-in.
- Check for crashes, lost or duplicate entries, incorrect day rollover, accessibility problems, and confusing offline states.
- Record release-blocking defects as GitHub issues and fix all critical issues.

Done when seven consecutive days finish without an unresolved critical issue.

#### Phase 9F: Internal TestFlight Release

Status: pending successful personal beta.

- Increment the build number, archive the app, and validate the archive in Xcode Organizer.
- Complete App Store Connect privacy answers and support information.
- Upload an internal TestFlight build and install it cleanly on the iPhone and Watch.
- Recheck launch, permissions, Watch installation, core tracking, backup, export, and deletion from the distributed build.

Done when the internal TestFlight build passes the clean-install smoke test on the user's devices.

Deliverables:

- Error states.
- Loading states.
- Empty states.
- Better charts.
- App icon.
- Real-device HealthKit testing.
- TestFlight preparation.

Done when:

- App is usable for one full week of personal tracking.
- No critical crashes in daily flows.
- Setup and privacy docs are clear.

Phase 9 done status: code-side polish and beta preparation are implemented and both simulator targets build. Final completion requires the signed iPhone/Watch checks and one full week without an unresolved critical issue.

## Phase 10: Future Ideas

Only consider these after the MVP loop works:

Status: not implemented.

- Date-range pauses for training sessions.
- One-tap move or copy of a workout to another day.
- Richer one-day schedule exceptions beyond resting for the day.
- Nutrition database barcode/search integration.
- Streaks and habit analytics.
- Subscription/payment model.
- Android version.
