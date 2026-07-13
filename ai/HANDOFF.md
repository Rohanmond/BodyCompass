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

## Partially Implemented

### Phase 4: Structured Training

The generic daily task schedule is implemented. The weekly strength/swimming program is not.

Required starting split:

| Day | Session |
| --- | --- |
| Monday | Chest + triceps |
| Tuesday | Back + biceps, then swimming |
| Wednesday | Legs |
| Thursday | Swimming |
| Friday | Upper body |
| Saturday | Arms, then swimming |
| Sunday | Swimming |

Still required:

- separate versioned training-routine models,
- detailed exercises, warm-ups, sets, rep ranges, RIR/RPE, rest, substitutions, and progression rules,
- strength set and swimming-session logs,
- manual weekly editing and one-day exceptions,
- routine history and rollback,
- Coach proposals with Confirm, Edit, or Reject,
- safeguards for fatigue, pain, equipment, experience, and swimming load.

Manual user edits can activate directly after review. Coach-generated changes must remain pending until explicit confirmation.

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

Continue Phase 4 in small verified milestones:

1. Add pure `BodyCompassCore` models for routines, days, sessions, prescriptions, logs, exceptions, versions, and pending proposals.
2. Add tests to `BodyCompassCoreCheck`, including routine validation and conservative double progression.
3. Seed the exact weekly split above without inventing fixed starting weights.
4. Collect training experience, available equipment, limitations/injuries, and swimming duration/intensity before generating detailed prescriptions.
5. Add a weekly routine screen and today's session screen, reachable from Today.
6. Add manual editing, one-day exceptions, local persistence, version history, and rollback.
7. Add workout logging and progression suggestions.
8. Add a mock structured Coach proposal flow with before/after diff and Confirm/Edit/Reject. Real providers belong to Phase 6.

Keep the generic daily task schedule and structured training routine separate. The former tracks habits; the latter owns programming, performance, and progression.

## Completion Criteria for Structured Training

- The seeded split survives app relaunch.
- User can view exactly what to do today.
- Strength prescriptions include sets, rep ranges, effort, rest, and substitutions.
- User can log load, reps, and effort; swimming supports duration, distance, and intensity.
- Manual edits create a new version and can be rolled back.
- A one-day move does not mutate the repeating routine.
- Progression suggestions are deterministic and tested.
- Coach cannot activate a proposal without confirmation.
- Invalid routines and unsafe/missing-context proposals produce clear UI states.
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
