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
- Current phase: Phases 0-4 and Phase 4W W1-W2 are implemented and simulator-build verified. Real-device Watch/HealthKit checks and W3-W5 remain.
- Recommended next work: validate W1-W2 on the paired devices, then start W3 after collecting swimming preferences. Phase 5 meal capture remains the next non-Watch phase.

## Prime Directive

BodyCompass should be useful for daily fat-loss discipline before it becomes fancy. Prioritize:

- real user data,
- reliable goal projection,
- fast meal logging,
- honest AI confidence,
- privacy and API key safety,
- beginner-friendly docs.
