# BodyCompass Model Handoff

Last audited: July 13, 2026

Use this file as the authoritative starting point for Claude, ChatGPT, Gemini, Codex, or another coding model. Read the linked product and engineering documents before changing code.

## Repository State

- Repository: `Rohanmond/BodyCompass`
- Primary branch: `main`
- Last feature commit before this handoff: `65126bb`
- iOS deployment target: iOS 17
- App: native SwiftUI under `ios/BodyCompass`
- Shared logic: Swift package target `BodyCompassCore`
- Backend: dependency-light Node 20 API under `server`
- Persistence today: `UserDefaults` on iOS and in-memory backend state only
- AI today: mock OpenAI and Gemini provider functions; no real provider HTTP calls

Local generated files may appear as `ios/BodyCompass/.swiftpm/` and `server/pnpm-lock.yaml`. Do not stage, delete, or redesign package management around them unless the user explicitly requests it. The documented backend workflow uses npm.

## Verified Baseline

The following passed during the July 13, 2026 audit:

- `swift run BodyCompassCoreCheck`
- `npm test` with 3 passing backend tests
- Xcode iOS Simulator build with `CODE_SIGNING_ALLOWED=NO`

This verifies compilation and existing automated checks. It does not verify real Apple Health data, notification delivery, camera behavior, or device signing.

## Implemented

### Foundation and iOS App

- Working Xcode project and shared `BodyCompass` scheme.
- Five tabs: Today, Meals, Goal, History, and Coach.
- First-run onboarding and profile editing.
- Local profile persistence with Codable JSON in `UserDefaults`.
- 12% body-fat projection with aggressive, optimum, and conservative timelines.

### Health and Daily Accountability

- HealthKit authorization-request flow.
- Independent queries for steps, active energy, workouts, sleep, weight, body fat, and resting heart rate.
- Pull-to-refresh and refresh-on-open behavior.
- Persistent daily manual overrides for weight, body fat, and sleep.
- Editable generic daily task schedule with categories, completion, reorder, and reminder times.
- Daily and rolling seven-day adherence calculations.
- Metric-aware next-best-action logic.
- Local notification scheduling implementation.

### Backend Scaffold

- Routes for health, goal projection, meal analysis, chat, and health snapshots.
- Goal projection tests.
- Mock dual-provider meal and chat responses.

### Phase 4: Structured Training

The generic daily task schedule and the weekly strength/swimming program are both implemented and simulator-build verified.

- Pure models in `Sources/BodyCompassCore/TrainingRoutine.swift`, `TrainingSeed.swift`, and `TrainingLogs.swift`: routines, days, sessions, prescriptions, set/swim logs, one-day exceptions, versions, validation, day-level diffing, edit-review warnings, proposals, and a deterministic conservative double-progression advisor. All covered by `BodyCompassCoreCheck`.
- The exact starting split is seeded and survives relaunch (Mon chest+triceps, Tue back+biceps then swimming, Wed legs, Thu swimming, Fri upper body, Sat arms then swimming, Sun swimming).
- A setup questionnaire (experience, equipment, limitations, swim duration/intensity) gates detailed prescription generation; no starting weights are ever invented.
- `App/TrainingStore.swift` owns persistence (UserDefaults) for versions, setup, exceptions, logs, and the pending proposal.
- Screens: `TrainingWeekView` (week, history, rollback, proposal entry), `TrainingSessionView` (today's prescriptions, progression hints, set/swim logging, rest-day exceptions), `TrainingEditorViews` (setup questionnaire, day editor, exercise editor with substitution swapping), `RoutineProposalView` (before/after diff, Confirm/Edit/Reject, staleness handling). Today tab links to session and week.
- Manual edits validate, warn on material volume increases or losing the only rest day, and activate directly as a new version. Coach proposals stay pending until explicit confirmation; a proposal built against an older version is stale and cannot be applied; proposals are refused entirely when setup context is missing.

Remaining Phase 4 niceties (deferred): date-range pauses, one-tap move/copy between days, and UI for non-rest one-day exceptions (the core `TrainingDayException` already supports arbitrary replacement sessions).

## Partially Implemented

### Phase 5: Meals

- Meal UI, notes field, analysis model, endpoint, and mock providers exist.
- Camera/photo picker, upload, typed API client, real providers, correction persistence, and history do not exist.

### Phase 6: Coach

- UI tabs and mock backend endpoint exist.
- Real chat transport, profile/health/meal/training context, conversation persistence, safety classification, and structured routine proposals do not exist.

### Phase 7: History and Weekly Photos

- History placeholder exists.
- Charts, weekly review, standardized front/side/back capture, private upload, visual comparison, and dual-AI body-fat range analysis do not exist.

Photo body-fat output must be a non-clinical range with confidence and limitations, never an exact measurement.

## Not Implemented

- Real OpenAI and Gemini API calls.
- Typed iOS backend client.
- Database, authentication, or private object storage.
- Export and complete deletion controls.
- TestFlight/App Store preparation.
- Real-device HealthKit and notification verification.

## Recommended Next Work

Phase 4 is complete. Continue with Phase 5 (Meals) in small verified milestones:

1. Add a camera/photo picker to the Meal Log screen (PhotosPicker first; camera needs a real device).
2. Add a typed iOS API client for the backend meal-analysis endpoint.
3. Send the photo plus portion notes to the backend; keep mock providers working without API keys.
4. Show OpenAI, Gemini, and reconciled estimates; let the user correct the final values.
5. Persist corrected meals locally and show meal history.

Phase 6 (Coach) should reuse the existing `RoutineChangeProposal` confirmation contract when providers start generating routine changes — the Confirm/Edit/Reject flow and staleness handling are already built.

Keep the generic daily task schedule and structured training routine separate. The former tracks habits (`AppStore`); the latter owns programming, performance, and progression (`TrainingStore`).

## Completion Criteria for Structured Training

All met in the July 13, 2026 implementation:

- The seeded split survives app relaunch (persisted routine versions).
- User can view exactly what to do today (`TrainingSessionView` from Today).
- Strength prescriptions include sets, rep ranges, effort, rest, and substitutions.
- User can log load, reps, and effort; swimming supports duration, distance, and intensity.
- Manual edits create a new version and can be rolled back (restore copies forward).
- A one-day exception does not mutate the repeating routine.
- Progression suggestions are deterministic and tested in `BodyCompassCoreCheck`.
- Coach cannot activate a proposal without confirmation; stale proposals cannot apply.
- Invalid routines produce validation alerts; missing-setup proposals are refused with an explanation.
- Swift check, backend tests, and Xcode Simulator build pass.

## Non-Negotiable Product Rules

- API keys remain backend-only.
- Call both OpenAI and Gemini for real meal, coach, and progress-photo analysis unless the product plan is explicitly changed.
- Preserve raw provider outputs and show a reconciled result.
- Never silently apply an AI routine change.
- Do not guess fixed workout loads without performance history.
- Protect sensitive progress photos: metadata removal, private storage, deletion, and no public URLs.
- Do not diagnose conditions or reinforce extreme deficits, unsafe training, or eating-disorder behavior.
- The user is learning Swift; keep setup and code explanations beginner-friendly.

## Engineering Notes

- `BodyCompassCore` must remain UI-, HealthKit-, notification-, and network-free.
- Some core Swift files are compiled by both Swift Package Manager and the Xcode app target.
- New Swift files must be added to `BodyCompass.xcodeproj/project.pbxproj`; merely creating a file does not attach it to the app target.
- The Xcode project is currently maintained manually. Preserve existing groups and target membership.
- Use conditional `canImport(BodyCompassCore)` imports where the current dual-build pattern requires them.
- Keep API keys out of iOS source, plist files, logs, fixtures, and commits.
- Do not claim HealthKit or notifications are device-verified until tested on a signed iPhone.

## Required Reading

1. `docs/prd.md`
2. `docs/phases.md`
3. `docs/training-plan.md`
4. `ai/architecture.md`
5. `ai/data-model.md`
6. `ai/api-contract.md`
7. `ai/coding-guidelines.md`
8. `ai/commands.md`
