# API Contract

Base URL: `http://localhost:8080`

All `/api/*` routes require `Authorization: Bearer <BODYCOMPASS_API_TOKEN>` when that environment variable is configured. Local development without a token uses the private `local-owner` account. Production refuses to start without separate API and image-storage secrets.

## `GET /health`

Returns service status.

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

Each successful estimate contains a title, calorie range, macros, confidence, likely mistakes, recommendation, and provider mode (`live` or `mock`). A failed provider returns `mode: "error"`; the reconciled result remains available when the other provider succeeds.

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

Progress photos must remain private, have metadata removed, and be deletable by the user.

The request requires `currentPhotos` with unique `front`, `side`, and `back` poses plus confirmations for morning capture, consistent lighting/distance, and full-body framing. `previousPhotos` and recent health context are optional. JPEG, PNG, and WebP are accepted; each decoded image is capped at 6 MB and all photos at 18 MB.

## Persistent Account Routes

- `PUT /api/profile`: upserts the private user's profile.
- `PUT /api/schedule`: replaces the current daily schedule (maximum 200 items).
- `GET /api/health-snapshots`: returns up to 365 persisted daily snapshots.
- `POST /api/meals/save` and `DELETE /api/meals`: save/delete accepted meal metadata and its encrypted private image.
- `POST /api/progress-check-ins/save` and `DELETE /api/progress-check-ins`: save/delete accepted three-angle check-ins and encrypted images.
- `GET /api/data/export?includeImages=false`: exports all account JSON. Set `includeImages=true` to include decrypted image bytes as base64.
- `DELETE /api/data`: deletes all database rows and private images. The JSON body must contain `{ "confirmation": "DELETE MY BODYCOMPASS DATA" }`.

Meal and progress analysis routes process uploads without persisting them. Only explicit post-review save routes write accepted records. Private image filenames are random, encrypted with AES-256-GCM, and never exposed through a public/static route.
