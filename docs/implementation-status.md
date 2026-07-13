# BodyCompass Implementation Status

Last updated: July 13, 2026

This page is the quick progress summary. See `docs/phases.md` for detailed deliverables and completion criteria.
Coding models should start with `ai/HANDOFF.md` for the audited repository handoff.

## Phase Status

| Phase | Status | Current Result |
| --- | --- | --- |
| Phase 0: Foundation | Complete | Repo structure, Swift core, Node backend scaffold, tests, and documentation exist. |
| Phase 1: Real iOS Project | Complete | The SwiftUI app builds successfully for the iOS Simulator. |
| Phase 2: Profile and Goal Setup | Complete | First-run onboarding, profile editing, local persistence, and live 12% projection are implemented. |
| Phase 3: HealthKit Daily Sync | Implemented; device check pending | Permission flow, daily metric queries, and manual fallback entries compile; actual Apple Health permissions and data require a signed iPhone run. |
| Phase 4: Schedule and Training Plan | Complete (simulator-verified) | Daily schedule, adherence, next action, and reminders plus the full structured training program: seeded weekly split, setup questionnaire, exercise prescriptions, set/swim logging, deterministic progression, versioned editing with rollback, one-day rest exceptions, and a mock coach proposal Confirm/Edit/Reject flow. |
| Phase 4W: Apple Watch Companion | In progress | W1 sync/offline foundation and W2 strength basics compile: HealthKit workout lifecycle, live heart rate/energy, set logging, rest timer, and haptics. Physical-device validation, WorkoutKit swimming, mirroring, and recovery guidance remain. |
| Phase 5: Meal Photo Logging | Partial | UI and mock dual-provider response exist; photo upload and real AI calls are missing. |
| Phase 6: Coach Chat | Partial | Chat UI and mock endpoint exist; real contextual provider calls are missing. |
| Phase 7: Weekly Review and Photos | Partial | History placeholder exists. Weekly progress-photo capture, comparison, and AI body-fat range analysis are planned but not built. |
| Phase 8: Persistence and Accounts | Not started | Database, private image storage, auth, export, and deletion are missing. |
| Phase 9: Polish and Beta | Not started | Real-device testing, accessibility, reliability, and TestFlight work are missing. |
| Phase 10: Future Ideas | Not started | Post-MVP enhancements remain intentionally deferred. |

## Latest Completed Work

- Added pure structured-training models to `BodyCompassCore`: routines, days, sessions, exercise prescriptions, set/swim logs, one-day exceptions, versions, validation, day-level diffing, edit-review warnings, and coach change proposals.
- Added a deterministic conservative double-progression advisor (baseline → add reps → add ~2.5% load, minimum 1 kg; pain notes force a caution state) covered by `BodyCompassCoreCheck` assertions.
- Seeded the exact weekly split (Mon chest+triceps, Tue back+biceps + swim, Wed legs, Thu swim, Fri upper body, Sat arms + swim, Sun swim) with no invented starting weights; it persists across relaunch.
- Added a training setup questionnaire (experience, equipment, limitations, swim duration/intensity) that gates detailed prescription generation.
- Added `TrainingStore` with local persistence for versions, setup, exceptions, logs, and proposals.
- Added the weekly routine screen, today's session screen (reachable from Today), day/exercise editors with substitution swapping, version history with rollback, one-day rest exceptions, and strength/swim logging sheets.
- Added a mock Coach proposal flow with reasons, recovery impact, before/after diff, staleness detection, and Confirm/Edit/Reject; proposals never activate without explicit confirmation and are refused without setup context.
- Added an embedded watchOS companion target with a shared scheme, HealthKit workout capability, cached routine sync, and durable UUID-based Watch log delivery/acknowledgement.
- Added the first Watch strength experience: today's session list, HealthKit start/pause/resume/end, live heart rate and energy, load/reps/RIR logging, rest countdown, and haptics. Manual offline swim logging bridges to the planned WorkoutKit phase.

## Verified

- `swift run BodyCompassCoreCheck` passes, including the new training model, validation, exception, diff, progression, and proposal assertions.
- `npm test` passes with three backend tests.
- The BodyCompass Xcode target builds successfully for the iOS Simulator with the eight new Swift files attached.
- The BodyCompass Watch App scheme builds successfully for the generic watchOS Simulator SDK destination.
- HealthKit data access and reminder delivery are not verifiable in a build-only check and remain real-device items.

Verification rerun: July 13, 2026.

## Next

- On a signed iPhone run, confirm the notification-permission prompt, reminder delivery, and real HealthKit reads.
- Follow `docs/apple-watch-setup.md` to validate routine sync, HealthKit workout saving, live metrics, offline queueing, and exact-once merge on the paired Series 10 and iPhone.
- Before W3, confirm pool/open-water mode, pool length, and whether swimming should primarily use BodyCompass or WorkoutKit in Apple's Workout app.
- Phase 5: camera/photo picker, meal upload, typed API client, and correction persistence.
- Phase 6: real provider chat with profile/health/meal/training context, reusing the existing proposal confirmation contract.
