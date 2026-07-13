# BodyCompass AI Context

This folder makes the repo AI-native. Future agents should start here before editing code.

## Read Order

1. `HANDOFF.md` - authoritative audited state, constraints, and next work.
2. `product-context.md` - what BodyCompass is and who it is for.
3. `architecture.md` - how the iOS app, Swift core, and backend fit together.
4. `implementation-status.md` - compact phase status.
5. `coding-guidelines.md` - repo-specific engineering rules.
6. `commands.md` - verification and local run commands.
7. `api-contract.md` - backend route shapes.
8. `data-model.md` - core and planned entities.
9. `ai-provider-strategy.md` - OpenAI and Gemini behavior.
10. `next-agent-brief.md` - immediately recommended implementation slice.

## Current Snapshot

- Product: native iOS fat-loss coach focused on reaching 12% body fat.
- Frontend: SwiftUI iOS app under `ios/BodyCompass`.
- Core logic: Swift package `BodyCompassCore`.
- Backend: dependency-light Node API under `server`.
- AI mode: call both OpenAI and Gemini for meal analysis and coach chat.
- Current phase: Phases 0-6 plus Phase 4W WorkoutKit handoff/basic result import are implemented and simulator-build verified. Real-device WorkoutKit/HealthKit, live provider, and physical-camera checks remain.
- Recommended next software phase: Phase 8 database persistence, private object storage, accounts/private-user mode, export, and complete deletion. Paired-device Watch and physical-camera/live-provider validation remain independent verification tracks.

## Prime Directive

BodyCompass should be useful for daily fat-loss discipline before it becomes fancy. Prioritize:

- real user data,
- reliable goal projection,
- fast meal logging,
- honest AI confidence,
- privacy and API key safety,
- beginner-friendly docs.
