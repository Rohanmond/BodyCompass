# Setup

## Backend

```sh
cd server
cp .env.example .env
npm install
npm run dev
```

Without API keys, the backend returns deterministic mock responses. Add real keys to `server/.env` when ready:

- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `GEMINI_API_KEY`
- `GEMINI_MODEL`

## iOS

Open the Xcode project:

```text
ios/BodyCompass/BodyCompass.xcodeproj
```

The meal client connects to `http://127.0.0.1:8080` by default, which works from the iOS Simulator when the backend is running on the Mac. On a physical iPhone, set `HOST=0.0.0.0` in `server/.env`, change `BODYCOMPASS_API_BASE_URL` in the app Info plist to the Mac's LAN URL, such as `http://192.168.1.20:8080`, and keep both devices on the same trusted network. Production must use HTTPS.

The camera is unavailable in most simulator configurations; use Photo Library there and validate Camera on a signed iPhone.

HealthKit requires:

- HealthKit capability enabled in Xcode.
- `NSHealthShareUsageDescription` in the app Info configuration.
- A real device for the most reliable HealthKit behavior.

For detailed Xcode steps, see `docs/xcode-phase-1.md`.

## Command-Line Checks

```sh
cd ios/BodyCompass
swift run BodyCompassCoreCheck

cd ../../server
npm test
```
