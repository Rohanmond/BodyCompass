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
  "imageBase64": "base64-image-bytes",
  "imageMimeType": "image/jpeg",
  "context": {
    "targetProteinGrams": 130
  }
}
```

Response:

```json
{
  "openai": { "provider": "openai", "mode": "live" },
  "gemini": { "provider": "gemini", "mode": "live" },
  "reconciled": {
    "title": "Chicken rice bowl",
    "caloriesRange": [620, 780],
    "proteinGrams": 42,
    "carbsGrams": 86,
    "fatGrams": 22,
    "confidence": 0.68,
    "likelyMistakes": ["Confirm cooking oil"],
    "recommendation": "Confirm the rice and oil portions before saving."
  }
}
```

The endpoint accepts JPEG, PNG, and WebP, caps decoded images at 8 MB, and does not persist the upload. Missing keys select deterministic mock mode. One provider may return `{ "mode": "error" }`; reconciliation uses the successful provider with reduced confidence. Both failures return HTTP 502.

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
  "combined": {
    "answer": "Use the weekly trend rather than one weigh-in.",
    "nextAction": "Complete today's planned strength session.",
    "safetyNotice": "",
    "routineProposal": null,
    "confidence": "dual_provider"
  },
  "openai": { "provider": "openai", "mode": "live" },
  "gemini": { "provider": "gemini", "mode": "live" }
}
```

The actual request also carries bounded goal, schedule/adherence, active routine/setup, and recent workout context. Provider answers may include a routine instruction with up to four `make_rest_day`, `update_swim`, or `update_exercise` operations. This is never an active routine: iOS must resolve known targets, validate the complete week, and create a pending `RoutineChangeProposal` for Confirm/Edit/Reject.

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

Storage is a per-user SQLite upsert keyed by day. `GET /api/health-snapshots` returns up to 365 records.

## `POST /api/progress-check-ins/analyze`

JSON request:

- required front, side, and back base64 images with MIME types,
- morning, consistent-lighting/distance, and full-body confirmations,
- recent weight and health trend,
- optional previous front, side, and back images and accepted range.

Response:

```json
{
  "openai": {
    "provider": "openai",
    "mode": "live",
    "bodyFatRange": [16, 20],
    "confidence": 0.62,
    "imageQuality": "good",
    "visibleChanges": [],
    "limitations": [],
    "suggestions": [],
    "nextWeekAction": "Keep capture conditions consistent."
  },
  "gemini": {},
  "reconciled": {
    "bodyFatRange": [16, 21],
    "confidence": 0.6,
    "imageQuality": "good",
    "visibleChanges": [],
    "limitations": [],
    "suggestions": [],
    "nextWeekAction": "Keep the current deficit and improve sleep consistency."
  }
}
```

The endpoint validates poses, MIME types, base64, standardized-capture confirmations, 6 MB per-image size, and 18 MB total decoded size. The iOS client re-renders selected images before upload to strip source metadata. The server does not persist images or create public URLs. Missing provider keys use deterministic mocks; one provider may fail without losing the reconciled response.

## Persistent Account Routes

All routes below use the authenticated private user:

- `PUT /api/profile`
- `PUT /api/schedule`
- `POST /api/meals/save`
- `DELETE /api/meals` with `{ "id": "..." }`
- `POST /api/progress-check-ins/save`
- `DELETE /api/progress-check-ins` with `{ "id": "..." }`
- `GET /api/data/export`
- `DELETE /api/data` with exact confirmation text

Accepted meal/progress save routes persist metadata in SQLite and reject photo fields. Analysis endpoints use photos transiently and remain non-persistent. Exports contain no image bytes. Startup migration purges legacy photo files and database references.

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
