# Backend Deployment

BodyCompass is local-first, but AI requests and private metadata backup need the Node backend. Production must run behind HTTPS. Meal and progress photos are transient analysis inputs: the server does not save them, and backups contain metadata only.

## What Is Ready

- A non-root Node 22 container in `server/Dockerfile`.
- Fail-fast production checks for bearer auth, stable owner identity, durable storage, and both AI provider keys.
- `/health/live` for process liveness and `/health/ready` for SQLite readiness.
- Graceful shutdown on `SIGTERM` and `SIGINT`.
- A durable `/data` volume in `server/compose.yaml`.
- Consistent SQLite backup plus checksum, integrity verification, and guarded restore commands.

The remaining Phase 9D work is choosing a host, connecting HTTPS, setting its secrets, and validating the signed iPhone against that deployed URL.

## 1. Prepare Production Secrets

Never commit `.env.production`. The example is safe to commit.

```sh
cd server
cp .env.production.example .env.production
openssl rand -hex 32
```

Put the generated value in `BODYCOMPASS_API_TOKEN`. Use a stable private value for `BODYCOMPASS_USER_ID`, then add fresh OpenAI and Gemini keys. Keys previously pasted into chat or exposed elsewhere should be revoked and replaced before deployment.

Production startup stops with a clear error when required settings are missing. `BODYCOMPASS_STORAGE_SECRET` is not required because current builds do not retain photos; it exists only for local cleanup compatibility with older data.

## 2. Run the Container Locally

Docker Desktop must be running.

```sh
cd server
docker compose up --build -d
curl http://127.0.0.1:8080/health/live
curl http://127.0.0.1:8080/health/ready
docker compose logs api
```

Both health calls should return `"ok": true`. The Compose port intentionally binds only to localhost. A production HTTPS proxy or hosting platform should be the only public entry point.

Stop without deleting the data volume:

```sh
docker compose down
```

Do not add `-v`; that would remove the named metadata volume.

## 3. Put It Behind HTTPS

Choose a host that supports a persistent disk/volume and HTTPS, then deploy `server/Dockerfile` with:

- Container port `8080`.
- Persistent volume mounted at `/data`.
- Health check path `/health/ready`.
- All values from `.env.production` stored in the host's secret manager.
- A stable HTTPS hostname, for example `https://api.example.com`.

Do not deploy SQLite to an ephemeral filesystem or to multiple simultaneously-writing replicas. This MVP is a private single-user service and should run as one instance.

In Xcode, set `BODYCOMPASS_API_BASE_URL` to the HTTPS hostname for the release configuration. On the iPhone, open **Goal**, tap the shield/lock button for **Data & Privacy**, and enter the same `BODYCOMPASS_API_TOKEN`.

## 4. Back Up Metadata

The command creates a consistent SQLite snapshot and adjacent `.json` manifest. The manifest records a SHA-256 checksum and explicitly states that the backup contains no photos.

For a direct Node deployment:

```sh
cd server
npm run backup -- /secure-backups/bodycompass-2026-07-14.sqlite
```

For Docker Compose:

```sh
docker compose exec api npm run backup -- /data/backups/bodycompass-2026-07-14.sqlite
docker compose cp api:/data/backups/bodycompass-2026-07-14.sqlite ./bodycompass-2026-07-14.sqlite
docker compose cp api:/data/backups/bodycompass-2026-07-14.sqlite.json ./bodycompass-2026-07-14.sqlite.json
```

Keep both files together. Keep at least one encrypted copy outside the production server and test restoration regularly.

## 5. Complete a Restore Drill

Restoration replaces the live database, so stop the API first. The command refuses to run without `--confirm`, validates the manifest/checksum, runs SQLite integrity checks, and preserves the previous database beside the restored one.

```sh
cd server
npm run restore -- /secure-backups/bodycompass-2026-07-14.sqlite --confirm
npm start
curl http://127.0.0.1:8080/health/ready
```

After restart, verify the iPhone can back up, export photo-free JSON, and delete a disposable test record. A local automated restore drill is covered by `npm test`; Phase 9D is complete only after the same drill succeeds on the chosen production host.

For Docker Compose, place the backup and manifest under `/data/backups`, stop the API, run a one-off restore container, and restart:

```sh
docker compose down
docker compose run --rm api npm run restore -- /data/backups/bodycompass-2026-07-14.sqlite --confirm
docker compose up -d
```

## Release Checklist

- HTTPS certificate is valid and HTTP redirects to HTTPS.
- One app instance uses a durable `/data` volume.
- Provider keys and bearer token exist only in the host secret manager.
- `/health/live` and `/health/ready` are healthy after a restart.
- A fresh backup exists off-host and its restore drill passes.
- Signed iPhone backup, export, and deletion pass against production.
- No API key appears in the iOS app, repository, image history, or logs.
