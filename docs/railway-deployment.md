# Railway Hobby Deployment

This is the selected production path for the private BodyCompass backend. Railway Hobby currently has a $5 monthly minimum that includes the first $5 of usage. BodyCompass uses one Singapore service and one `/data` volume because its metadata database is SQLite.

Do not paste API keys into source files, Xcode, GitHub issues, screenshots, or deployment logs. Rotate any key that was previously shared in chat before following this guide.

## 1. Create the Railway Project

1. Sign in at `https://railway.com` with GitHub.
2. Upgrade the workspace to **Hobby**.
3. Select **New Project**, then **Deploy from GitHub repo**.
4. Choose `Rohanmond/BodyCompass` and branch `main`.
5. Open the new service's **Settings**.
6. Set **Root Directory** to `/server`.
7. Set **Railway Config File** to `/server/railway.json` if Railway did not detect it automatically.

The committed configuration selects the Dockerfile, one Singapore replica, `/health/ready`, automatic restart, and a 15-second graceful shutdown window.

## 2. Add the Durable Volume

1. On the project canvas, right-click the BodyCompass service or choose **New**.
2. Select **Volume** and attach it to the BodyCompass service.
3. Set the mount path to `/data`.
4. Keep one service replica. Do not horizontally scale a SQLite deployment.

Railway-mounted volumes can initially be owned by root. Set `RAILWAY_RUN_UID=0` in the next step. The container entrypoint uses that access only to prepare `/data`, then starts Node as the unprivileged `node` user.

## 3. Add Variables

Open the service's **Variables** tab and add:

```text
NODE_ENV=production
HOST=0.0.0.0
BODYCOMPASS_DATA_DIR=/data
BODYCOMPASS_STORAGE_SECRET=<new 64-character hex value>
BODYCOMPASS_AUTH_SECRET=<different new 64-character hex value>
RESEND_API_KEY=<Resend API key>
BODYCOMPASS_EMAIL_FROM=BodyCompass <login@your-verified-domain.example>
OPENAI_API_KEY=<new OpenAI key>
OPENAI_MODEL=gpt-5.4
GEMINI_API_KEY=<new Gemini key>
GEMINI_MODEL=gemini-3.1-flash-lite
RAILWAY_RUN_UID=0
```

Do not set `PORT`; Railway injects it. Generate the server-only storage secret locally with:

```sh
openssl rand -hex 32
```

Store this server secret in a password manager. It is never entered in BodyCompass or shared with users.

Before friend testing, verify a domain in Resend and use an address on that domain for `BODYCOMPASS_EMAIL_FROM`. Add the Resend key directly in Railway Variables; never paste it into a chat or commit it. OTP requests intentionally return HTTP 503 in production until email delivery is configured.

## 4. Deploy and Enable HTTPS

1. Apply the staged Railway changes and deploy.
2. Watch the build/deploy logs for `BodyCompass API listening`.
3. Open **Settings > Networking > Public Networking**.
4. Select **Generate Domain**.
5. Open `https://<generated-domain>/health/ready`.

Expected response:

```json
{
  "ok": true,
  "service": "bodycompass-server",
  "persistence": "ready"
}
```

Railway terminates HTTPS at its edge. The generated Railway domain is sufficient for the private beta; buying a custom domain is optional.

## 5. Connect the iPhone

1. In Xcode, set the release value of `BODYCOMPASS_API_BASE_URL` to the generated `https://` Railway domain with no trailing slash.
2. Build and reinstall BodyCompass on the iPhone.
3. In BodyCompass, open **Goal**, tap the shield/lock button, then open **Data & Privacy**.
4. Sign out if needed, enter your email, request a six-digit code, and enter the code received by email. The first successful code creates the account.
5. Confirm the private-backup status becomes healthy after onboarding.

Verify a disposable record before using real history:

- Save a test meal result.
- Confirm it appears after relaunch.
- Export BodyCompass JSON and confirm it contains metadata but no photos.
- Delete the disposable result.

## 6. Configure Backups and Spending

1. Open the attached volume's **Backups** tab.
2. Enable daily and weekly backups.
3. Create one manual backup after the first successful iPhone sync.
4. In workspace billing, set a low hard usage limit and enable usage alerts.
5. Follow `docs/deployment.md` to create an independent checksum-verified SQLite backup and complete the Phase 9D restore drill.

Railway volume snapshots are useful, but an independent BodyCompass backup remains required before Phase 9D is marked complete.

## Troubleshooting

- **Configuration error at startup:** confirm every production variable is present and placeholders were replaced.
- **Cannot write to `/data`:** confirm the volume is mounted at `/data` and `RAILWAY_RUN_UID=0` is configured.
- **Health check fails:** do not set a fixed `PORT`; verify `HOST=0.0.0.0` and the path is `/health/ready`.
- **Code email does not arrive:** confirm `RESEND_API_KEY`, the verified sending domain, and `BODYCOMPASS_EMAIL_FROM`; then check Resend delivery logs and the spam folder.
- **App still calls the Mac:** update `BODYCOMPASS_API_BASE_URL`, rebuild, and reinstall the signed app.
