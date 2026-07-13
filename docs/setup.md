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

Phase 8 persistence variable:

- `BODYCOMPASS_STORAGE_SECRET`: server-only random value required in production. Users never enter it in the app.
- `BODYCOMPASS_DATA_DIR`: SQLite directory; defaults to `server/server-data` and is ignored by Git.
- `BODYCOMPASS_AUTH_SECRET`: separate random server secret used to hash one-time email challenges.

Passwordless email sign-in uses Resend in production:

- Create a Resend API key and set `RESEND_API_KEY` in the server environment.
- Verify a domain you own in Resend by adding its SPF and DKIM DNS records.
- Set `BODYCOMPASS_EMAIL_FROM`, for example `BodyCompass <login@bodycompass.example>`.
- Do not paste the API key into chat, Xcode, source files, or the iOS app.

Local development works without Resend: the request endpoint returns a development-only code that the iOS form fills automatically. Production deliberately fails closed until email delivery is configured.

Use the checksum-verified `npm run backup` and `npm run restore` commands instead of copying an active SQLite file. Meal and progress photos are analysis-only and are excluded from history, backup, and export. API keys stay only in the server environment; the app stores only the optional bearer token in Keychain. See `docs/deployment.md` for the container, HTTPS, durable-volume, and restore-drill steps.

## iOS

Open the Xcode project:

```text
ios/BodyCompass/BodyCompass.xcodeproj
```

All API clients connect to `http://127.0.0.1:8080` by default, which works from the iOS Simulator when the backend runs on the Mac. Enter an email on the first screen, then verify the six-digit code. First verification creates the account; later verifications sign in. For a physical iPhone using a local Mac server, set `HOST=0.0.0.0`, point `BODYCOMPASS_API_BASE_URL` to the Mac's LAN URL, and keep both devices on the same trusted network. Production must use HTTPS.

BodyCompass remains local-first: device writes succeed immediately and server backup retries on future launches/edits. Open Today → Settings → Account & Privacy to inspect the signed-in account and backup status, sign out, create an export, or delete the account.

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
