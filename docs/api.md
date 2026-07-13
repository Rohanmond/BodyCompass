# API Contract

Base URL: `http://localhost:8080`

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

Sends a coaching question to both providers and returns a combined answer with provider details.

## `POST /api/progress-check-ins/analyze` (Planned)

Accepts standardized weekly front, side, and back progress photos plus recent weight and health trends. Both AI providers return a non-clinical body-fat range, confidence, visible changes, limitations, and suggestions. The reconciled result emphasizes week-over-week direction instead of claiming an exact measurement.

Progress photos must remain private, have metadata removed, and be deletable by the user.
