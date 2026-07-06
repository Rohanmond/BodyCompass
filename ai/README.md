# BodyCompass AI Context

This folder makes the repo AI-native. Future agents should start here before editing code.

## Read Order

1. `product-context.md` - what BodyCompass is and who it is for.
2. `architecture.md` - how the iOS app, Swift core, and backend fit together.
3. `implementation-status.md` - what phases are implemented and what is still missing.
4. `coding-guidelines.md` - repo-specific engineering rules.
5. `commands.md` - verification and local run commands.
6. `api-contract.md` - backend route shapes.
7. `data-model.md` - core entities and planned storage shape.
8. `ai-provider-strategy.md` - how OpenAI and Gemini should be used.
9. `next-agent-brief.md` - recommended next steps.

## Current Snapshot

- Product: native iOS fat-loss coach focused on reaching 12% body fat.
- Frontend: SwiftUI iOS app under `ios/BodyCompass`.
- Core logic: Swift package `BodyCompassCore`.
- Backend: dependency-light Node API under `server`.
- AI mode: call both OpenAI and Gemini for meal analysis and coach chat.
- Current phase: Phase 1 implemented and simulator-build verified.

## Prime Directive

BodyCompass should be useful for daily fat-loss discipline before it becomes fancy. Prioritize:

- real user data,
- reliable goal projection,
- fast meal logging,
- honest AI confidence,
- privacy and API key safety,
- beginner-friendly docs.
