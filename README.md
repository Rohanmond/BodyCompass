# BodyCompass

Native iOS fat-loss coach for reaching 12% body fat with HealthKit history, daily adherence tracking, weekly progress-photo analysis, meal-photo calorie analysis, and dual AI feedback from OpenAI and Gemini.

## Structure

- `ios/BodyCompass` - SwiftUI iOS app source plus testable core logic.
- `server` - Node API with SQLite persistence, encrypted private images, health logs, AI analysis, Coach chat, and provider routing.
- `docs` - Product, setup, API, and HealthKit notes.
- `ai` - AI-native repo context for future agents and implementation planning.

## MVP

- HealthKit permission flow and daily metric snapshots.
- Evidence-based 12% body-fat timeline projection.
- Meal-photo analysis through both ChatGPT and Gemini.
- Standardized weekly progress photos with an AI-estimated body-fat range and trend feedback.
- Daily schedule and adherence dashboard.
- Weekly strength/swimming routine with exercise, set, rep, rest, and progression guidance.
- Coach-proposed routine updates that require user confirmation.
- Weekly review and history trends.
- Coach chat with combined answer and provider comparison.
- Local-first private backup with bearer authentication, export, and complete deletion controls.

## Planning Docs

- Current implementation status: `docs/implementation-status.md`
- Training plan requirements: `docs/training-plan.md`
- Apple Watch companion plan: `docs/apple-watch-plan.md`
- Apple Watch Xcode/device setup: `docs/apple-watch-setup.md`
- Product requirements: `docs/prd.md`
- Step-by-step phases: `docs/phases.md`
- Beginner Swift guide: `docs/swift-beginner-guide.md`
- Xcode Phase 1 guide: `docs/xcode-phase-1.md`
- AI repo context: `ai/README.md`
- Cross-model implementation handoff: `ai/HANDOFF.md`
- Phase 9 beta and TestFlight checklist: `docs/beta-checklist.md`

## Quick Start

```sh
cd server
cp .env.example .env
npm install
npm test
npm run dev
```

Open `ios/BodyCompass/BodyCompass.xcodeproj` in Xcode and run the `BodyCompass` app target. Core goal logic can also be tested from the command line:

```sh
cd ios/BodyCompass
swift run BodyCompassCoreCheck
```

See `docs/setup.md` for full setup.

Before a beta build, run `./scripts/release-preflight.sh --build` from the repository root.

If Swift/iOS is new for you, start with `docs/swift-beginner-guide.md`.
