# BodyCompass

Native iOS fat-loss coach for reaching 12% body fat with HealthKit history, daily adherence tracking, meal-photo calorie analysis, and dual AI feedback from OpenAI and Gemini.

## Structure

- `ios/BodyCompass` - SwiftUI iOS app source plus testable core logic.
- `server` - Node API for health logs, meal analysis, coach chat, and provider routing.
- `docs` - Product, setup, API, and HealthKit notes.
- `ai` - AI-native repo context for future agents and implementation planning.

## MVP

- HealthKit permission flow and daily metric snapshots.
- Evidence-based 12% body-fat timeline projection.
- Meal-photo analysis through both ChatGPT and Gemini.
- Daily schedule and adherence dashboard.
- Weekly review and history trends.
- Coach chat with combined answer and provider comparison.

## Planning Docs

- Product requirements: `docs/prd.md`
- Step-by-step phases: `docs/phases.md`
- Beginner Swift guide: `docs/swift-beginner-guide.md`
- Xcode Phase 1 guide: `docs/xcode-phase-1.md`
- AI repo context: `ai/README.md`

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

If Swift/iOS is new for you, start with `docs/swift-beginner-guide.md`.
