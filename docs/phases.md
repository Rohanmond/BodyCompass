# BodyCompass Step-by-Step Phases

This roadmap is written so each phase produces something useful and testable. Do not jump to App Store or payments before the core coach loop works.

## Current Implementation Status

Quick summary: `docs/implementation-status.md`.

Implemented:

- Phase 0 is implemented as the initial repo foundation.
- Swift core goal projection check passes with `swift run BodyCompassCoreCheck`.
- Backend unit tests pass with `npm test`.
- Backend health and goal projection endpoints have been smoke tested locally.
- PRD, setup docs, HealthKit notes, API notes, and beginner Swift guide exist.
- Phase 1 Xcode project, shared scheme, Info.plist, entitlements, and asset catalog exist.
- Phase 1 iOS simulator build succeeds with Xcode.
- Phase 2 onboarding, profile persistence, profile editing, and live goal recalculation are implemented.
- Phase 3 HealthKit permission flow, real daily metric queries, manual fallback entries, and Today-screen refresh are implemented.

Partially implemented:
- Phase 4 still needs the weekly training plan, exercise prescriptions, performance logging, progression, and coach confirmation workflow.
- Phase 5 and Phase 6 have backend mock provider flows and UI placeholders, but not real photo upload, real provider API calls, or persistence.
- Phase 7 has a History tab placeholder, but not real weekly analytics or progress-photo analysis yet.
- Phase 1 still needs you to open Xcode locally and choose signing for real-device runs.

Not implemented yet:

- Camera/photo picker.
- Weekly progress-photo capture, comparison, and AI body-fat range estimation.
- Database-backed storage.
- Real OpenAI/Gemini HTTP integrations.
- App Store/TestFlight readiness.

## Phase 0: Foundation

Goal: make the repo understandable and runnable.

Deliverables:

- Repo structure: `ios/`, `server/`, `docs/`.
- SwiftUI app shell with tabs.
- Swift core goal projection logic.
- Node backend with mock AI providers.
- Beginner docs for Swift and setup.

Status: implemented.

Implemented in this phase:

- Root repo docs and `.gitignore`.
- Swift package at `ios/BodyCompass`.
- SwiftUI app source files for Today, Meals, Goal, History, and Coach tabs.
- Shared Swift design components and mock app state.
- HealthKit service wrapper with the intended read types.
- Swift body-fat goal projection logic.
- Swift command-line verification through `BodyCompassCoreCheck`.
- Node backend with routes for health, goal projection, meal analysis, chat, and health snapshots.
- Mock OpenAI + Gemini provider flow.
- Backend goal projection tests.
- PRD, phased roadmap, API notes, HealthKit notes, setup guide, and Swift beginner guide.

Done when:

- `swift run BodyCompassCoreCheck` passes.
- `npm test` passes.
- Backend `/health` and `/api/goal/projection` work locally.

Phase 0 done status: done.

## Phase 1: Real iOS Project

Goal: make the app open and run from Xcode on simulator/device.

Status: implemented and simulator-build verified.

Implemented in this phase:

- `BodyCompass.xcodeproj` exists.
- Shared `BodyCompass` scheme exists.
- Existing SwiftUI app files are attached to the app target.
- Bundle ID is set to `com.rohanmondal.bodycompass`.
- App Info.plist includes HealthKit, camera, and photo library usage descriptions.
- HealthKit entitlements file exists.
- Placeholder asset catalog exists.
- Xcode beginner guide exists at `docs/xcode-phase-1.md`.
- Simulator build succeeds with `xcodebuild` when full Xcode is selected.

Deliverables:

- Create proper Xcode iOS project or workspace.
- Attach existing SwiftUI files to the iOS app target.
- Configure bundle ID, signing, app icon placeholder, and deployment target.
- Enable HealthKit capability.
- Add Info usage descriptions for HealthKit and camera/photo access.

Local verification note:

- Terminal verification with `xcodebuild` requires the active developer directory to point to full Xcode, not Command Line Tools.
- Real-device runs still require your Apple signing team in Xcode.

Done when:

- App runs in iOS Simulator.
- App runs on a real iPhone.
- All five tabs render without crashing.

## Phase 2: Profile and Goal Setup

Goal: let the user enter real starting data.

Status: implemented and simulator-build verified.

Implemented in this phase:

- First-run onboarding for name, age, height, weight, current body fat, target body fat, and preferred workout time.
- Input validation prevents an empty name or a target body-fat value that is not below the current estimate.
- Profile persistence using Codable JSON in `UserDefaults`.
- Automatic goal projection recalculation whenever the profile changes.
- Profile editing from the Goal tab.
- Clear aggressive, optimum, and conservative timeline estimates.

Deliverables:

- Onboarding screens for age, height, weight, current body fat, target body fat, and schedule preference.
- Persist profile locally.
- Show the initial 12% projection.
- Add clear explanation of optimum, aggressive, and conservative timelines.

Done when:

- User can complete onboarding.
- Goal tab reflects entered data.
- User can edit profile values.

Phase 2 done status: done.

## Phase 3: HealthKit Daily Sync

Goal: connect BodyCompass to Apple Health data.

Status: implemented and build-verified. Real-device HealthKit data still needs a signed device run.

Implemented in this phase:

- Connect Apple Health banner on the Today screen with a one-tap permission request.
- Real daily queries for steps, active energy, workout minutes, and last night's sleep.
- Most-recent-sample queries with short look-back windows for weight, body-fat percentage, and resting heart rate.
- Independent per-metric queries so denied or partial permissions never break the rest of the dashboard.
- Manual fallback entry for weight, body fat, and sleep that overrides imported values and persists per day.
- Today screen refreshes HealthKit data on open and with pull-to-refresh.
- Weight and body-fat metric cards on the Today dashboard with manual-entry source labels.

Deliverables:

- HealthKit permission screen.
- Read daily steps, active energy, weight, body-fat percentage, sleep, workouts, and resting heart rate.
- Manual fallback fields when HealthKit data is missing.
- Refresh data when Today screen opens.

Done when:

- App handles denied, partial, and full HealthKit permissions.
- Today dashboard shows real or manual metrics.
- Missing values do not break goal calculations.

Phase 3 done status: implementation complete and simulator target builds; confirm the permission sheet, partial/denied access, and real metrics on a signed iPhone run.

## Phase 4: Daily Schedule, Training Plan, and Adherence

Goal: make the app a daily accountability system.

Status: partially implemented. Daily schedule and adherence are build-verified; structured training plans and coach-confirmed updates are not implemented.

Implemented in this phase:

- Editable daily schedule with add, edit, delete, and reorder in a dedicated editor screen.
- Each task has a category (weigh-in, nutrition, training, steps, sleep, other) used for icons and next-best-action ranking.
- Tap-to-complete tracking on the Today screen, persisted per day in `UserDefaults`.
- Daily adherence score plus a rolling 7-day adherence average from persisted `DayAdherenceRecord` history.
- Automatic daily roll that clears completion at a new day while preserving the task list and prior scores.
- Next-best-action logic that ranks training, protein, steps, sleep, and remaining tasks using real metrics and meal protein.
- Optional local reminders (UserNotifications) with a master toggle and a per-task reminder time.
- Pure schedule/adherence/next-best-action logic in `BodyCompassCore`, exercised by `BodyCompassCoreCheck`.

Training plan still to implement:

- Seed the user's Monday-to-Sunday chest/triceps, back/biceps, legs, swimming, upper-body, and arms/swimming split.
- Add a weekly routine view and a detailed session screen.
- Store exercises, warm-ups, working sets, rep ranges, target RIR/RPE, rest time, substitutions, and coaching notes.
- Log completed load, reps, effort, pain/limitations, and swimming duration/intensity.
- Suggest double-progression changes from recent performance without automatically applying them.
- Let Coach return a structured routine-change proposal with reasons, recovery impact, and a before/after diff.
- Require Confirm, Edit, or Reject before changing the active routine.
- Version routines so a confirmed change can be reviewed or rolled back.

Deliverables:

- Editable daily schedule.
- Completion tracking.
- Daily adherence score.
- Next best action logic based on meals, protein, steps, workout, sleep, and schedule.
- Optional local reminders.

Done when:

- User can check off daily tasks.
- Today screen explains the most important remaining action.
- Weekly adherence score can be calculated.
- User can see what exercises, sets, reps, effort, and rest to perform today.
- Coach cannot modify the active routine until the user confirms the proposal.

Phase 4 done status: daily schedule foundation is complete; training programming and coach approval workflow remain.

## Phase 5: Meal Photo Logging

Goal: make meal logging fast and useful.

Status: partially implemented.

Implemented so far:

- Meal Log screen exists.
- Portion notes field exists.
- Backend meal analysis endpoint exists.
- Backend calls mock OpenAI and Gemini provider functions.
- Reconciled estimate shape exists.

Deliverables:

- Camera/photo picker.
- Portion notes field.
- Meal upload to backend.
- OpenAI + Gemini analysis.
- Reconciled calorie/macro range.
- User correction flow.

Done when:

- User can log a meal photo.
- App shows OpenAI, Gemini, and combined estimates.
- User can correct the final calories/macros.
- Corrected meal is saved to history.

## Phase 6: Coach Chat

Goal: connect AI answers to the user’s real goal data.

Status: partially implemented.

Implemented so far:

- Coach tab exists.
- Combined, ChatGPT, and Gemini UI tabs exist.
- Backend chat endpoint exists.
- Backend calls mock OpenAI and Gemini provider functions.

Deliverables:

- Chat UI with combined, ChatGPT, and Gemini tabs.
- Backend chat endpoint with user profile, latest health snapshot, meals, and schedule context.
- Safety rules for medical, injury, extreme deficit, and eating-disorder topics.

Done when:

- User can ask coaching questions.
- Both providers respond.
- Combined answer gives one practical recommendation.

## Phase 7: Weekly Review and History

Goal: turn logs and standardized progress photos into progress decisions.

Status: partially implemented.

Implemented so far:

- History tab placeholder exists.
- Planned history sections are visible.
- Progress-photo capture and AI analysis are not implemented yet.

Deliverables:

- Weight trend view.
- Body-fat trend view.
- Meal adherence view.
- Workout and sleep consistency view.
- Weekly projection recalculation.
- Optional weekly morning photo check-in with front, side, and back guidance.
- Capture-quality checks for consistent pose, framing, distance, and lighting.
- Private progress-photo upload with metadata removal and deletion controls.
- Dual-provider visual analysis returning a body-fat range, confidence, visible trend, and limitations.
- Comparison with previous check-ins using weight and activity trends as additional context.
- User correction or rejection of the AI body-fat estimate.
- Plain-language review: what worked, what failed, what changes next.

Done when:

- User can see why the timeline changed.
- User can compare weekly photos and see a non-clinical estimate range without false precision.
- Weekly review produces a next-week action plan.

## Phase 8: Backend Persistence and Accounts

Goal: stop relying on in-memory/mock data.

Status: not implemented.

Deliverables:

- Database schema for users, profiles, snapshots, meals, schedule items, and chats.
- Basic auth or private single-user mode.
- Private image storage for meal and progress photos.
- Delete/export data controls.

Done when:

- Data survives server restart.
- User can delete meal images and health logs.
- API keys remain server-side only.

## Phase 9: Polish and Beta

Goal: make it reliable enough for daily use.

Status: not implemented.

Deliverables:

- Error states.
- Loading states.
- Empty states.
- Better charts.
- App icon.
- Real-device HealthKit testing.
- TestFlight preparation.

Done when:

- App is usable for one full week of personal tracking.
- No critical crashes in daily flows.
- Setup and privacy docs are clear.

## Phase 10: Future Ideas

Only consider these after the MVP loop works:

Status: not implemented.

- Nutrition database barcode/search integration.
- Apple Watch companion.
- Streaks and habit analytics.
- Subscription/payment model.
- Android version.
