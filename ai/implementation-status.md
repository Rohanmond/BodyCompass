# Implementation Status

Source of truth for detailed phase status: `docs/phases.md`.
Human-readable quick summary: `docs/implementation-status.md`.

## Implemented

- Phase 0 foundation.
- Phase 1 Xcode project.
- Phase 2 onboarding, profile editing, and local persistence.
- SwiftUI app shell with five tabs.
- Swift core goal projection logic.
- Xcode simulator build verification.
- Node backend with mock AI providers.
- Docs: PRD, phases, setup, HealthKit, API, Swift beginner guide, Xcode guide.

## Partially Implemented

- HealthKit service wrapper exists, but metric queries are not implemented.
- Today schedule uses mock data.
- Meal Log UI exists, but photo picker and upload are not implemented.
- Backend AI provider functions are mocks.
- Coach chat UI and endpoint exist, but real context wiring is not implemented.
- History UI is placeholder only.
- Weekly progress-photo workflow and AI analysis are planned but not implemented.

## Not Implemented

- Real HealthKit reads.
- Camera/photo picker.
- Progress-photo capture, private storage, comparison, and body-fat range analysis.
- Real OpenAI and Gemini HTTP calls.
- Database and object storage.
- Auth/private user mode.
- TestFlight/App Store readiness.

## Latest Verified Commands

- `swift run BodyCompassCoreCheck`
- `npm test`
- Xcode simulator build with full Xcode selected and `CODE_SIGNING_ALLOWED=NO`
