# Implementation Status

Source of truth for detailed phase status: `docs/phases.md`.
Human-readable quick summary: `docs/implementation-status.md`.
Authoritative cross-model handoff: `ai/HANDOFF.md`.

Last audited: July 14, 2026.

## Implemented

- Phase 0 foundation.
- Phase 1 Xcode project.
- Phase 2 onboarding, profile editing, and local persistence.
- Phase 3 HealthKit permission flow, metric queries, manual fallbacks, and Today refresh; the signed-device full-permission path works, while partial/denied checks remain.
- Phase 4 daily schedule, persisted completion, adherence history, next-best-action logic, and reminders.
- Phase 4 structured training: pure core models (routines, days, sessions, prescriptions, logs, exceptions, versions, proposals), seeded weekly split, setup questionnaire gating detailed prescriptions, weekly routine and today's-session screens, day/exercise editing with new versions and rollback, one-day rest exceptions, set/swim logging, deterministic conservative double progression, and a mock coach proposal Confirm/Edit/Reject flow.
- Phase 4W W1: embedded watchOS target/shared scheme, HealthKit capability, latest-routine application-context sync, persistent Watch cache, durable strength/swim queues, UUID-idempotent iPhone merge, and acknowledgement cleanup.
- Phase 5 meal logging: camera/library capture, transient compressed JPEG upload, typed iOS API client, live-or-mock OpenAI and Gemini meal adapters, resilient reconciliation, editable nutrition confirmation, and photo-free result history.
- Phase 6 Coach Chat: typed transport, bounded app context, live-or-mock OpenAI and Gemini adapters, safety classification, local conversation history, one next action, and validated confirmed-only routine proposals.
- Phase 7 weekly review and photos: persisted health history, native trends, weekly summaries, recalculated goal projection, standardized transient three-angle analysis, photo-free result history, dual-provider visual ranges, correction/rejection, and deletion.
- Phase 8 persistence/accounts: SQLite metadata durability, private single-user bearer auth, no-photo persistence enforcement, legacy-photo cleanup, local-first iOS backup, Keychain token, and photo-free JSON export.
- Phase 9C live AI and signed-iPhone meal/progress camera plus Coach confirmation validation.
- Phase 9D production configuration, health probes, non-root container, checksum-verified backup/restore tooling, and a live Railway Southeast Asia service with durable SQLite storage.
- SwiftUI app shell with five tabs.
- Swift core goal projection logic.
- Xcode simulator build verification.
- Node backend with real meal and Coach provider adapters plus mock fallback when keys are absent.
- Docs: PRD, phases, setup, HealthKit, API, Swift beginner guide, Xcode guide.

## Partially Implemented

- Phase 4 extras: date-range pauses, one-tap move/copy of sessions between days, and non-rest one-day exception UI (the core model supports arbitrary replacement sessions).
- Phase 4W Apple Workout migration is simulator-build verified: WorkoutKit strength/swim mapping, iPhone scheduling, Watch handoff, runtime strength fallback, Pool/Open Water selection, completed-workout UUID matching, duration/energy/distance import, and durable manual strength details. Paired-device verification remains.
- Phase 8/9D production HTTPS hosting is live; the host restore drill and authenticated deployed-service iPhone verification remain.

## Not Implemented

- Phase 4W physical-device WorkoutKit/HealthKit validation; recovery-aware suggestions are implemented.
- TestFlight/App Store readiness.

## Latest Verified Commands

- `swift run BodyCompassCoreCheck`
- `npm test` (35 tests)
- Xcode simulator build with full Xcode selected and `CODE_SIGNING_ALLOWED=NO`
- Watch app build for the generic watchOS Simulator SDK destination with `CODE_SIGNING_ALLOWED=NO`

Full-permission HealthKit reads and notification delivery are signed-iPhone verified. Partial/denied HealthKit, Watch Connectivity, and Watch workout capture still require paired-device checks.

## Important Distinction

The `ScheduleItem` flow is a generic daily habit/task schedule owned by `AppStore`. The structured weekly strength/swimming routine is a separate system owned by `TrainingStore` on top of the pure models in `Sources/BodyCompassCore/Training*.swift`. Keep them separate: the former tracks habits, the latter owns programming, performance, and progression.
