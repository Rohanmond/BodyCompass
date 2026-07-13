# API Contract

Base URL: `http://localhost:8080`

All API routes except requesting and verifying an email code require an account session using `Authorization: Bearer <session-token>`. Verification returns an opaque 30-day token; only its SHA-256 hash is stored by the server. The iOS app handles this header automatically and keeps the session in Keychain.

## Authentication

- `POST /api/auth/email/request`: `{ "email" }`. Creates a random six-digit, single-use challenge that expires after 10 minutes. Requests are IP-throttled and each address has a 60-second resend cooldown.
- `POST /api/auth/email/verify`: `{ "challengeId", "code" }`. Verifies the address, creates the account when needed, consumes the challenge, and returns a 30-day session.
- `GET /api/auth/me`: validates the stored session and returns the current user.
- `POST /api/auth/logout`: revokes the current session.

Legacy password registration/login routes remain temporarily available for already-installed builds during the passwordless migration. They are not presented in the current iOS UI.

In local development without `RESEND_API_KEY`, the request response includes `developmentCode`. Production never returns the code and requires Resend delivery.

## `GET /health`

Returns service liveness for backward compatibility. `/health/live` is the explicit process liveness probe and `/health/ready` verifies SQLite is accessible; readiness returns HTTP 503 when persistence is unavailable. Health probes do not expose secrets or user data.

## `POST /api/health-snapshots`

Stores one daily HealthKit/manual snapshot.

```json
{
  "date": "2026-07-06",
  "weightKg": 78.2,
  "bodyFatPercentage": 18.5,
  "steps": 10400,
  "activeEnergyKcal": 720,
  "sleepHours": 7.2
}
```

## `POST /api/goal/projection`

Returns the target-weight and timeline estimate.

## `POST /api/meals/analyze`

Accepts meal context and an optional image payload:

```json
{
  "notes": "Chicken rice bowl, home cooked, about one tablespoon oil",
  "imageBase64": "base64-encoded-image-bytes",
  "imageMimeType": "image/jpeg",
  "context": {
    "targetProteinGrams": 130
  }
}
```

JPEG, PNG, and WebP are accepted. Decoded images are limited to 8 MB and the JSON request is limited to 12 MB. The image is processed in memory and is not stored by this endpoint. The backend sends the request to both providers and returns:

- `openai`
- `gemini`
- `reconciled`

Each successful estimate contains a title, calorie range, macros, confidence, likely mistakes, recommendation, green signs, red flags, concrete improvements, one next action, and provider mode (`live` or `mock`). These fields turn the estimate into a decision: what is helping, what may slow the goal, what to reduce/add/swap/measure, and what to do next. A failed provider returns `mode: "error"`; the reconciled result remains available when the other provider succeeds.

## `POST /api/chat`

Sends a coaching question plus bounded app context to both providers:

```json
{
  "message": "Should I adjust my Sunday swim for recovery?",
  "context": {
    "profile": {},
    "today": {},
    "recentMeals": [],
    "schedule": [],
    "goal": {},
    "dailyAdherence": 0.8,
    "weeklyAdherence": 0.76,
    "training": {
      "setupComplete": true,
      "activeRoutine": {}
    }
  },
  "history": []
}
```

The message is limited to 2,000 characters and the JSON body to 500 KB. The response contains `combined`, `openai`, and `gemini`. Each successful answer includes text, one next action, a safety notice, and an optional bounded routine instruction. A routine instruction is only a proposal input; the iOS app matches it to known routine entities, validates the resulting week, and still requires Confirm/Edit/Reject.

## `POST /api/progress-check-ins/analyze`

Accepts standardized weekly front, side, and back progress photos plus recent weight and health trends. Both AI providers return a non-clinical body-fat range, confidence, visible changes, limitations, and suggestions. The reconciled result emphasizes week-over-week direction instead of claiming an exact measurement.

Progress photos must remain private, have metadata removed, and be discarded after analysis rather than persisted.

The request requires transient `currentPhotos` with unique `front`, `side`, and `back` poses plus confirmations for morning capture, consistent lighting/distance, and full-body framing. Recent health context and the prior accepted result are optional; prior photos are not retained or resent. JPEG, PNG, and WebP are accepted; each decoded image is capped at 6 MB and all photos at 18 MB.

## Persistent Account Routes

- `PUT /api/profile`: upserts the private user's profile.
- `PUT /api/schedule`: replaces the current daily schedule (maximum 200 items).
- `GET /api/health-snapshots`: returns up to 365 persisted daily snapshots.
- `POST /api/meals/save` and `DELETE /api/meals`: save/delete accepted meal metadata only. Save requests containing image fields are rejected.
- `POST /api/progress-check-ins/save` and `DELETE /api/progress-check-ins`: save/delete accepted result metadata only. Save requests containing photos are rejected.
- `GET /api/data/export`: exports account JSON without photo contents because photos are never retained.
- `DELETE /api/data`: deletes all database rows. The JSON body must contain `{ "confirmation": "DELETE MY BODYCOMPASS DATA" }`.
- `GET /api/usage`: returns the signed-in user's meal, Coach, and progress AI use, limits, remaining actions, and next UTC reset.

Meal and progress analysis routes process uploads in memory without persisting them. Explicit post-review save routes write accepted results and metadata only. Startup migration removes legacy local/server photo files and references from earlier builds.
