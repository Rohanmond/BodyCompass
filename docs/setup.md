# Setup

## Backend

```sh
cd server
cp .env.example .env
npm install
npm run dev
```

Without API keys, the backend returns deterministic mock responses. Add real keys when ready:

- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `GEMINI_API_KEY`
- `GEMINI_MODEL`

## iOS

Open `ios/BodyCompass` in Xcode. The SwiftUI app currently uses mock data and a local HealthKit service wrapper.

HealthKit requires:

- HealthKit capability enabled in Xcode.
- `NSHealthShareUsageDescription` in the app Info configuration.
- A real device for the most reliable HealthKit behavior.

## Command-Line Checks

```sh
cd ios/BodyCompass
swift run BodyCompassCoreCheck

cd ../../server
npm test
```
