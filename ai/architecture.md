# Architecture

## High-Level Shape

```mermaid
flowchart TD
    User["User on iPhone"] --> IOS["SwiftUI iOS App"]
    IOS --> Core["BodyCompassCore Swift Logic"]
    IOS --> HealthKit["Apple HealthKit"]
    IOS <--> Watch["BodyCompass watchOS Companion"]
    Watch --> HealthKit
    IOS --> API["BodyCompass Node API"]
    API --> OpenAI["OpenAI Provider"]
    API --> Gemini["Gemini Provider"]
    API --> Store["Private DB / Object Storage"]
    IOS --> Photos["Meal and Weekly Progress Photos"]
    Photos --> API
```

## iOS App

Path: `ios/BodyCompass`

Responsibilities:

- SwiftUI screens and navigation.
- HealthKit authorization and metric reads.
- Camera/photo picker for meals and standardized weekly progress check-ins.
- Local user state and manual fallback inputs.
- Versioned weekly routine, session logging, and pending coach-change proposals.
- Sync routine/session data with the offline-capable watchOS companion.
- Display AI comparison and reconciled recommendations.
- Persist Coach exchanges locally and validate AI routine instructions before creating pending proposals.

Current app tabs:

- Today
- Meals
- Goal
- History
- Coach

## Apple Watch and Apple Workout (In Progress)

- Apple Workout exclusively owns active strength/swimming lifecycle and sensor metrics.
- WorkoutKit creates, schedules, and opens BodyCompass plans in Apple Workout.
- Watch Connectivity transfers routine versions, setup context, queued logs, and background updates.
- HealthKit maps completed Apple workouts back by WorkoutPlan/session UUID.
- Watch remains functional offline and reconciles logs idempotently after reconnecting.

Implemented now: Watch Connectivity transfers routine/history and durable manual logs. WorkoutKit maps strength and Pool/Open Water swims, schedules from iPhone, and opens Apple Workout from Watch. Structured strength uses a runtime-supported custom plan or open Traditional Strength Training fallback. Completed HealthKit workouts match the BodyCompass session UUID and expose duration, energy, and swimming distance. BodyCompass no longer starts a parallel workout session or mirrors lifecycle.

## Swift Core

Path: `ios/BodyCompass/Sources/BodyCompassCore`

Responsibilities:

- Body profile model.
- Daily health snapshot model.
- Meal analysis model.
- Provider estimate bundle and corrected meal-history model.
- 12% body-fat goal projection logic.

This code should stay pure and testable. Do not add HealthKit, network calls, or UI dependencies here.

## Backend

Path: `server`

Responsibilities:

- Keep OpenAI and Gemini API keys server-side.
- Analyze meals through both providers.
- Compare weekly progress photos through both providers using health trends as context.
- Create combined Coach answers with bounded user context and deterministic safety routing.
- Validate and reconcile structured training-plan proposals without activating them.
- Accept health snapshots and future persisted logs.
- Persist private account data in SQLite and encrypt accepted meal/progress images outside the public web surface.
- Authenticate the configured private owner, export their data, and delete relational records plus encrypted files.
- Calculate or mirror goal projections for API clients.

Current backend is dependency-light Node using `node:http`. Add dependencies only when they clearly help.

## Persistence

Current state:

- SQLite persists users, profiles, health snapshots, schedules, accepted meals, Coach exchanges, and progress check-ins in WAL mode.
- AES-256-GCM encrypted files persist accepted meal and progress photos under random non-public references.
- iOS remains local-first with `UserDefaults` metadata and complete-file-protected Application Support photos, then asynchronously backs up accepted records.
- A bearer token is optional for local private mode, required in production, and stored in iOS Keychain.

Future production work:

- HTTPS hosting with a durable volume and a tested backup/restore process.
- Managed relational/object storage only when deployment scale justifies replacing the SQLite/encrypted-file adapter.
- Multi-user identity only if BodyCompass becomes more than a private single-user app.

## Important Boundary

Never put OpenAI or Gemini API keys in the iOS app. All provider calls must go through `server`.

Progress photos are sensitive user data. Strip metadata before upload, avoid including the face where possible, never expose public URLs, and delete provider-bound temporary files after analysis.
