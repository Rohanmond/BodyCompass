# API Contract

Detailed public notes also live in `docs/api.md`.

## `GET /health`

Returns service status.

Response:

```json
{
  "ok": true,
  "service": "bodycompass-server"
}
```

## `POST /api/goal/projection`

Request:

```json
{
  "weightKg": 80,
  "bodyFatPercentage": 22,
  "targetBodyFatPercentage": 12,
  "adherenceScore": 0.8,
  "weeklyWeightTrendKg": -0.5
}
```

Response includes:

- current fat mass,
- current lean mass,
- target weight,
- fat to lose,
- aggressive/optimum/conservative weeks,
- daily deficit estimate,
- status,
- explanation.

## `POST /api/meals/analyze`

Request:

```json
{
  "notes": "Chicken rice bowl, home cooked, 1 serving, maybe 1 tbsp oil",
  "imageBase64": "optional-base64-image"
}
```

Response:

```json
{
  "openai": {},
  "gemini": {},
  "reconciled": {}
}
```

## `POST /api/chat`

Request:

```json
{
  "message": "What should I fix today?",
  "profile": {},
  "today": {},
  "recentMeals": []
}
```

Response:

```json
{
  "combined": "Combined coaching answer...",
  "openai": {},
  "gemini": {}
}
```

## `POST /api/health-snapshots`

Request:

```json
{
  "date": "2026-07-06",
  "weightKg": 80,
  "bodyFatPercentage": 22,
  "steps": 8420,
  "activeEnergyKcal": 640,
  "sleepHours": 7.1,
  "restingHeartRate": 58,
  "workoutMinutes": 45
}
```

Current storage is in-memory only.

## `POST /api/progress-check-ins/analyze` (Planned)

Multipart request:

- optional front, side, and back images,
- capture time and standardization confirmations,
- recent weight and health trend,
- optional previous check-in identifier.

Response:

```json
{
  "openai": {
    "bodyFatRange": { "minimum": 16, "maximum": 20 },
    "confidence": 0.62,
    "visibleChanges": [],
    "limitations": []
  },
  "gemini": {},
  "reconciled": {
    "bodyFatRange": { "minimum": 17, "maximum": 20 },
    "trend": "likely_decreasing",
    "nextWeekAction": "Keep the current deficit and improve sleep consistency."
  }
}
```

The endpoint must reject unsuitable images, remove metadata, avoid public image URLs, and return ranges rather than a single body-fat measurement.

## `GET /api/training/routine` (Planned)

Returns the active versioned weekly routine with strength exercises, swimming sessions, set and rep ranges, effort targets, rest periods, progression rules, and substitutions.

## `PUT /api/training/routine` (Planned)

Validates and saves a user-edited routine as a new active version. Manual user edits do not require Coach confirmation. The prior version remains available for rollback.

## `POST /api/training/day-exceptions` (Planned)

Creates a date-specific moved, replaced, or skipped session without changing the repeating weekly routine.

## `POST /api/training/logs` (Planned)

Stores completed strength sets or swimming-session results. Logged effort and performance inform future progression suggestions.

## `POST /api/training/proposals` (Planned)

Creates a pending routine-change proposal from Coach. The response includes a before/after diff, rationale, recovery impact, and structured routine version. Creating a proposal never changes the active routine.

## `POST /api/training/proposals/:id/decision` (Planned)

Request:

```json
{
  "decision": "confirm",
  "editedRoutine": null
}
```

`decision` must be `confirm`, `edit`, or `reject`. Only confirmation of a valid proposal activates a new routine version.
