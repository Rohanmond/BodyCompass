# BodyCompass Step-by-Step Phases

This roadmap is written so each phase produces something useful and testable. Do not jump to App Store or payments before the core coach loop works.

## Phase 0: Foundation

Goal: make the repo understandable and runnable.

Deliverables:

- Repo structure: `ios/`, `server/`, `docs/`.
- SwiftUI app shell with tabs.
- Swift core goal projection logic.
- Node backend with mock AI providers.
- Beginner docs for Swift and setup.

Status: started.

Done when:

- `swift run BodyCompassCoreCheck` passes.
- `npm test` passes.
- Backend `/health` and `/api/goal/projection` work locally.

## Phase 1: Real iOS Project

Goal: make the app open and run from Xcode on simulator/device.

Deliverables:

- Create proper Xcode iOS project or workspace.
- Attach existing SwiftUI files to the iOS app target.
- Configure bundle ID, signing, app icon placeholder, and deployment target.
- Enable HealthKit capability.
- Add Info usage descriptions for HealthKit and camera/photo access.

Done when:

- App runs in iOS Simulator.
- App runs on a real iPhone.
- All five tabs render without crashing.

## Phase 2: Profile and Goal Setup

Goal: let the user enter real starting data.

Deliverables:

- Onboarding screens for age, height, weight, current body fat, target body fat, and schedule preference.
- Persist profile locally.
- Show the initial 12% projection.
- Add clear explanation of optimum, aggressive, and conservative timelines.

Done when:

- User can complete onboarding.
- Goal tab reflects entered data.
- User can edit profile values.

## Phase 3: HealthKit Daily Sync

Goal: connect BodyCompass to Apple Health data.

Deliverables:

- HealthKit permission screen.
- Read daily steps, active energy, weight, body-fat percentage, sleep, workouts, and resting heart rate.
- Manual fallback fields when HealthKit data is missing.
- Refresh data when Today screen opens.

Done when:

- App handles denied, partial, and full HealthKit permissions.
- Today dashboard shows real or manual metrics.
- Missing values do not break goal calculations.

## Phase 4: Daily Schedule and Adherence

Goal: make the app a daily accountability system.

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

## Phase 5: Meal Photo Logging

Goal: make meal logging fast and useful.

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

Deliverables:

- Chat UI with combined, ChatGPT, and Gemini tabs.
- Backend chat endpoint with user profile, latest health snapshot, meals, and schedule context.
- Safety rules for medical, injury, extreme deficit, and eating-disorder topics.

Done when:

- User can ask coaching questions.
- Both providers respond.
- Combined answer gives one practical recommendation.

## Phase 7: Weekly Review and History

Goal: turn logs into progress decisions.

Deliverables:

- Weight trend view.
- Body-fat trend view.
- Meal adherence view.
- Workout and sleep consistency view.
- Weekly projection recalculation.
- Plain-language review: what worked, what failed, what changes next.

Done when:

- User can see why the timeline changed.
- Weekly review produces a next-week action plan.

## Phase 8: Backend Persistence and Accounts

Goal: stop relying on in-memory/mock data.

Deliverables:

- Database schema for users, profiles, snapshots, meals, schedule items, and chats.
- Basic auth or private single-user mode.
- Image storage for meal photos.
- Delete/export data controls.

Done when:

- Data survives server restart.
- User can delete meal images and health logs.
- API keys remain server-side only.

## Phase 9: Polish and Beta

Goal: make it reliable enough for daily use.

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

- Nutrition database barcode/search integration.
- Apple Watch companion.
- Progress photos with visual comparison.
- Custom workout plan.
- Streaks and habit analytics.
- Subscription/payment model.
- Android version.
