# BodyCompass Implementation Status

Last updated: July 14, 2026

This page is the quick progress summary. See `docs/phases.md` for detailed deliverables and completion criteria.
Coding models should start with `ai/HANDOFF.md` for the audited repository handoff.

## Phase Status

| Phase | Status | Current Result |
| --- | --- | --- |
| Phase 0: Foundation | Complete | Repo structure, Swift core, Node backend scaffold, tests, and documentation exist. |
| Phase 1: Real iOS Project | Complete | The SwiftUI app builds for Simulator and has been signed, installed, trusted, and launched successfully on the user's iPhone 17 Pro. |
| Phase 2: Profile and Goal Setup | Complete | First-run onboarding, profile editing, local persistence, and live 12% projection are implemented. |
| Phase 3: HealthKit Daily Sync | Signed-device primary flow verified | Full-permission HealthKit authorization and real weight, energy, resting-heart-rate, and daily reads work on the user's iPhone. Partial/denied permission exercises remain. |
| Phase 4: Schedule and Training Plan | Complete (simulator-verified) | Daily schedule, adherence, next action, and reminders plus the full structured training program: seeded weekly split, setup questionnaire, exercise prescriptions, set/swim logging, deterministic progression, versioned editing with rollback, one-day rest exceptions, and a mock coach proposal Confirm/Edit/Reject flow. |
| Phase 4W: Apple Watch Companion | Implemented; device check pending | Apple Workout ownership, WorkoutKit handoff, durable manual logs, completed-workout metrics, and deterministic recovery-aware post-workout guidance compile. Paired-device validation remains. |
| Phase 5: Meal Photo Logging | Complete; live API verified | Camera/library capture, compressed upload, real dual-provider adapters, comparison, correction, encrypted local photo history, and deletion are implemented. Live dual-provider notes-only analysis and fallback pass; physical-camera checks remain. |
| Phase 6: Coach Chat | Complete; live API verified | Contextual dual-provider chat, local history, safety routing, provider comparison, and validated confirmed-only routine proposals are implemented. Both providers and the reconciled next action pass live API validation. |
| Phase 7: Weekly Review and Photos | Complete (simulator-build verified) | Persisted HealthKit trends, weekly adherence/nutrition/training review, recalculated projection, standardized three-angle check-ins, protected local photos, comparison, dual-AI range analysis, correction/rejection, and deletion are implemented. Live-key and physical-camera checks remain. |
| Phase 8: Persistence and Accounts | Complete (simulator-build verified) | SQLite persistence, private single-user bearer auth, encrypted non-public image storage, local-first iOS backup, Keychain token, JSON export, and server/device deletion are implemented. Production deployment/restore checks remain. |
| Phase 9: Polish and Beta | In progress; primary iPhone and live AI checks verified | Signed launch, full-permission HealthKit, authenticated backup, local notification delivery, and Phase 9C dual-provider meal/Coach API checks pass. Physical cameras, progress-photo vision, Watch, and partial/denied HealthKit checks remain before deployment and beta gates. |
| Phase 10: Future Ideas | Not started | Post-MVP enhancements remain intentionally deferred. |

## Latest Completed Work

- Added pure structured-training models to `BodyCompassCore`: routines, days, sessions, exercise prescriptions, set/swim logs, one-day exceptions, versions, validation, day-level diffing, edit-review warnings, and coach change proposals.
- Added a deterministic conservative double-progression advisor (baseline → add reps → add ~2.5% load, minimum 1 kg; pain notes force a caution state) covered by `BodyCompassCoreCheck` assertions.
- Seeded the exact weekly split (Mon chest+triceps, Tue back+biceps + swim, Wed legs, Thu swim, Fri upper body, Sat arms + swim, Sun swim) with no invented starting weights; it persists across relaunch.
- Added a training setup questionnaire (experience, equipment, limitations, swim duration/intensity) that gates detailed prescription generation.
- Added `TrainingStore` with local persistence for versions, setup, exceptions, logs, and proposals.
- Added the weekly routine screen, today's session screen (reachable from Today), day/exercise editors with substitution swapping, version history with rollback, one-day rest exceptions, and strength/swim logging sheets.
- Added the Coach proposal contract with reasons, recovery impact, before/after diff, staleness detection, and Confirm/Edit/Reject; provider instructions never activate without explicit confirmation and are refused without setup context.
- Added an embedded watchOS companion target with a shared scheme, HealthKit workout capability, cached routine sync, and durable UUID-based Watch log delivery/acknowledgement.
- Retained the useful W2 manual layer: recent-history sync, stable acknowledged set history, previous-performance prefilling, substitutions, pain severity, rest timers, and optional haptics. The former custom HealthKit lifecycle/metrics UI was superseded and removed.
- Replaced the custom BodyCompass HealthKit workout lifecycle with WorkoutKit plans for strength and swimming. iPhone schedules; Watch opens Apple Workout; structured strength falls back safely when unsupported.
- Added Pool/Open Water selection at handoff time and completed-workout matching by session UUID with duration, energy, and swimming distance display.
- Completed W5 recovery coaching: persisted session RPE/soreness, best-effort Apple Workout heart-rate context, personalized deterministic recommendations, and next-session actions without automatic plan changes.
- Completed Phase 5 meal logging: camera and Photos picker, metadata-stripping JPEG preparation, typed iOS API transport, OpenAI and Gemini vision adapters, provider fallback/reconciliation, correction before save, private local photo history, and deletion.
- Completed Phase 6 Coach Chat: bounded profile/health/meal/adherence/training context, OpenAI and Gemini responses, deterministic safety routing, local conversation history, one next action, and validated routine instructions routed into Confirm/Edit/Reject proposals.
- Completed Phase 7 weekly review: persisted 180-day health snapshots, native weight/body-fat charts, seven-day adherence/nutrition/training summaries, trend-aware 12% projection, and a standardized front/side/back check-in flow.
- Added protected local progress-photo storage, metadata-stripping JPEG preparation, prior-week comparison, editable/rejectable visual ranges, deletion, and a bounded dual-provider progress-analysis API with quality and privacy rules.
- Completed Phase 8 persistence: SQLite records survive restart; meal/progress images use an AES-256-GCM private file vault; bearer auth, local-first iOS backup, Keychain token storage, export, and complete server/device deletion are wired end to end.
- Implemented Phase 9 code-side polish: iPhone/Watch icons, privacy manifests, local-first backup recovery, accessible metrics and trends, a 12% chart target, automated preflight, and a physical-device/TestFlight checklist.
- Added app-wide keyboard dismissal and refreshed the daily-use UI: priority-first Today hierarchy, varied metric colors, clearer HealthKit date windows, adherence progress, a visual goal summary, and improved Meals/Coach presentation. Simulator and signed-iPhone builds pass.
- Verified real HealthKit snapshot backup and the Debug-only 10-second notification banner/sound delivery on the signed iPhone.
- Verified live OpenAI and Gemini meal analysis, reconciliation, one-provider meal fallback, and contextual Coach responses. Provider transport now retries bounded 429/503 failures; Gemini defaults to the current `gemini-3.1-flash-lite` model.
- Created a Personal Team development certificate and provisioning profiles, then built, installed, trusted, and launched BodyCompass successfully on the user's physical iPhone 17 Pro. Xcode physical-Watch discovery remains deferred.

## Verified

- `swift run BodyCompassCoreCheck` passes, including training validation, progression, proposal, log reconciliation, and W5 recovery-advisor scenarios.
- `npm test` passes with 28 backend tests.
- The BodyCompass Xcode target builds successfully for the generic iOS Simulator destination with the meal services and embedded Watch app.
- The BodyCompass Watch App scheme builds successfully for the generic watchOS Simulator SDK destination.
- Phase 9 privacy manifests and 1024-pixel icon catalogs validate, and the polished iPhone and Watch targets build successfully.
- Full-permission HealthKit data access and local reminder delivery passed on the signed iPhone; partial/denied HealthKit paths and Watch integrations remain physical-device items.

Verification rerun: July 14, 2026.

## Next

- Continue Phase 9C on the signed iPhone: clear/poor meal photos, correction/deletion, Coach routine proposal confirmation, and the three-angle progress-photo flow. Return to partial/denied HealthKit and deferred Watch discovery before release.
- Follow `docs/apple-watch-setup.md` to validate WorkoutKit permission, iPhone scheduling, Watch handoff, Apple Workout capture, HealthKit import, offline queueing, and exact-once manual-log merge.
- Validate Phase 5 on a physical iPhone camera and with both provider API keys; mock mode remains available without keys.
- Validate Phase 6's live response and Confirm/Edit/Reject proposal flow in the signed-device UI; the live dual-provider API path is verified.
- Validate Phase 7 with a physical iPhone camera and both live provider keys; deterministic mock mode covers the full flow locally.
- Deploy Phase 8 behind HTTPS with durable volume backup, then perform a backup/restore drill using stable API/storage secrets.
- Run `./scripts/release-preflight.sh --build`, then complete the signed-device, Series 10, seven-day personal beta, and TestFlight gates in `docs/beta-checklist.md`.
