# Setup

## Backend

The persistent backend requires Node 22.5 or newer.

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

Phase 8 persistence variables:

- `BODYCOMPASS_API_TOKEN`: optional in local development and required in production. Enter the same value under Goal → Data & Privacy in the app.
- `BODYCOMPASS_USER_ID`: stable private account identifier; defaults to `local-owner`.
- `BODYCOMPASS_STORAGE_SECRET`: legacy cleanup compatibility only; new builds do not retain meal or progress photos.
- `BODYCOMPASS_DATA_DIR`: SQLite directory; defaults to `server/server-data` and is ignored by Git.

Back up the SQLite files. Meal and progress photos are analysis-only and are excluded from history, backup, and export. API keys stay only in `server/.env`; the app stores only the optional bearer token in Keychain.

## iOS

Open the Xcode project:

```text
ios/BodyCompass/BodyCompass.xcodeproj
```

All API clients connect to `http://127.0.0.1:8080` by default, which works from the iOS Simulator when the backend is running on the Mac. On a physical iPhone, first set a strong `BODYCOMPASS_API_TOKEN`, then set `HOST=0.0.0.0` in `server/.env`; the server refuses non-localhost binding without authentication. Change `BODYCOMPASS_API_BASE_URL` in the app Info plist to the Mac's LAN URL, such as `http://192.168.1.20:8080`, enter the token under Goal → Data & Privacy, and keep both devices on the same trusted network. Production must use HTTPS.

BodyCompass remains local-first: device writes succeed immediately and server backup retries on future launches/edits. Use the lock-shield button in Goal to inspect backup status, set the bearer token, create an export, or delete all BodyCompass data.

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
