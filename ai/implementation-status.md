# Implementation Status

Source of truth for detailed phase status: `docs/phases.md`.
Human-readable quick summary: `docs/implementation-status.md`.
Authoritative cross-model handoff: `ai/HANDOFF.md`.

Last audited: July 13, 2026.

## Implemented

- Phase 0 foundation.
- Phase 1 Xcode project.
- Phase 2 onboarding, profile editing, and local persistence.
- Phase 3 HealthKit permission flow, metric queries, manual fallbacks, and Today refresh; real-device verification remains.
- SwiftUI app shell with five tabs.
- Swift core goal projection logic.
- Xcode simulator build verification.
- Node backend with mock AI providers.
- Docs: PRD, phases, setup, HealthKit, API, Swift beginner guide, Xcode guide.

## Partially Implemented

- Phase 4 daily schedule, persisted completion, adherence history, next-best-action logic, and reminders exist. Editable weekly programming, one-day exceptions, set/rep logging, progression, version history, and coach-confirmed routine updates are not implemented.
- Meal Log UI exists, but photo picker and upload are not implemented.
- Backend AI provider functions are mocks.
- Coach chat UI and endpoint exist, but real context wiring is not implemented.
- History UI is placeholder only.
- Weekly progress-photo workflow and AI analysis are planned but not implemented.

## Not Implemented

- Camera/photo picker.
- Structured training routine, exercise prescriptions, workout logs, progression, and routine-change confirmation.
- Progress-photo capture, private storage, comparison, and body-fat range analysis.
- Real OpenAI and Gemini HTTP calls.
- Database and object storage.
- Auth/private user mode.
- TestFlight/App Store readiness.

## Latest Verified Commands

- `swift run BodyCompassCoreCheck`
- `npm test`
- Xcode simulator build with full Xcode selected and `CODE_SIGNING_ALLOWED=NO`

Real HealthKit reads and notification delivery must still be checked on a signed iPhone.

## Important Distinction

The implemented `ScheduleItem` flow is a generic daily habit/task schedule. It is not the planned weekly strength/swimming routine. Future models must introduce separate training models for prescriptions, performance logs, progression, versions, and Coach proposals.
