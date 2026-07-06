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
