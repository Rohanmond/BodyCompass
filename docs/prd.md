# BodyCompass PRD

## 1. Product Summary

BodyCompass is a native iOS fat-loss coaching app for users who want to reduce body fat to 12% with disciplined daily tracking. It combines Apple Health data, manual check-ins, weekly progress photos, meal-photo analysis, and dual AI feedback from OpenAI and Gemini.

The product should feel like a serious personal coach: direct, evidence-based, practical, and focused on the next action.

## 2. Primary Goal

Help the user understand:

- How long it will realistically take to reach 12% body fat.
- Whether today moved them closer to or further from the goal.
- What they should correct next in meals, activity, sleep, or schedule.

## 3. Target User

The initial target user is a focused adult fitness user who:

- Has an iPhone.
- Wants to reduce body fat, not just lose random weight.
- Is willing to log meals and follow a daily schedule.
- Wants AI feedback but still needs clear numbers and history.
- May not understand nutrition deeply and needs simple, direct coaching.

## 4. Core User Problems

- “I do not know how long it should take to reach 12% body fat.”
- “I eat something and do not know the calories or macros.”
- “I lose discipline because I cannot see daily accountability.”
- “Apple Health has my activity/sleep data, but it does not explain what to do.”
- “Generic AI advice is not connected to my real history.”
- “I cannot tell whether my physique is visibly changing from week to week.”
- “I know which body parts I want to train, but I need exact exercises, sets, reps, rest, and progression guidance.”

## 5. MVP Scope

### Must Have

- Native iOS SwiftUI app.
- Multi-user account creation, sign in, sign out, secure sessions, and per-user data isolation.
- Apple HealthKit read access for weight, body fat, steps, active energy, workouts, sleep, and resting heart rate.
- Manual fallback entries for missing HealthKit data.
- 12% body-fat projection engine.
- Today dashboard with schedule, calories, protein, activity, sleep, and next best action.
- Editable weekly strength and swimming routine with exercise prescriptions and completion tracking.
- Manual routine editor for moving sessions between days and changing exercises, sets, reps, rest, and recovery days.
- Coach-proposed routine changes with an explicit confirmation step.
- Meal logging with photo/context input.
- Backend endpoint that sends meal analysis to both OpenAI and Gemini.
- Reconciled calorie/macro estimate with confidence and warnings.
- Actionable meal verdict: green signs, red signs, what to reduce/add/swap/measure, and one next action.
- Coach chat with combined answer and separate provider outputs.
- Weekly review and history screen.
- Standardized weekly morning progress-photo check-in.
- AI visual progress comparison with a body-fat range, confidence, and corrective suggestions.
- Beginner-friendly setup and learning docs.

### Should Have

- User correction flow for meal estimates.
- Weekly projection recalculation from real trend data.
- Simple local notifications for schedule reminders.
- Analysis-only meal photos that are discarded instead of added to history.
- Apple Watch companion for active strength/swimming guidance, live workout metrics, quick logging, rest haptics, and offline sync.
- WorkoutKit scheduling/opening for all strength and swimming sessions; Apple Workout always owns active workout capture.

### Out of Scope for MVP

- App Store release.
- Android app.
- Paid subscriptions.
- Full nutrition database integration.
- Medical diagnosis or treatment advice.

## 6. Key User Flows

### Onboarding

1. User creates an account or signs in.
2. User enters age, height, weight, current body-fat estimate, and target body fat.
3. App explains that 12% timeline is an estimate.
4. User grants HealthKit permission or chooses manual mode.
5. App calculates starting projection and privately syncs it to that account.

### Daily Check-In

1. User opens Today screen.
2. App refreshes HealthKit data.
3. User sees progress against calories, protein, steps, workout, sleep, and schedule.
4. App gives one next best action.

### Training Session

1. App loads the planned session for the day.
2. User sees exercises, warm-up guidance, working sets, rep ranges, target effort, rest time, and substitutions.
3. User records completed sets, reps, and weight or marks a swimming session complete.
4. App suggests the next load or rep target using recent performance and recovery data.

### Coach Routine Update

1. User asks Coach to review or change the routine.
2. Coach considers goals, training history, available equipment, injuries or limitations, recent performance, sleep, adherence, and swimming load.
3. App shows the proposed changes as a before/after summary with reasons and recovery impact.
4. User chooses Confirm, Edit, or Reject.
5. Only a confirmed proposal becomes the active routine; the previous version remains in history and can be restored.

### Manual Routine Update

1. User opens the weekly routine editor.
2. User adds, removes, reorders, copies, or moves sessions and exercises.
3. User can create a one-day exception or update the repeating routine.
4. App summarizes changes and warns when recovery or weekly volume changes materially.
5. User saves a new active version and can later restore an older version.

Manual changes do not require Coach confirmation. Confirmation is required only when Coach proposes a change from chat.

### Apple Watch Workout

1. Today's prescribed session syncs to Apple Watch and remains available offline.
2. BodyCompass schedules or opens the plan in Apple Workout through WorkoutKit.
3. Apple Workout owns live metrics and workout controls; BodyCompass retains prescriptions and manual strength details.
4. User confirms sets, reps, load, effort, substitutions, or swimming work with minimal interaction.
5. Rest and interval haptics provide optional prompts.
6. Completed HealthKit metrics and BodyCompass logs sync back exactly once.
7. Post-workout suggestions use performance and recovery context; material routine changes still require confirmation.

### Meal Photo Analysis

1. User adds meal photo.
2. User adds portion notes, sauces/oil, restaurant/home, and serving count.
3. Backend calls OpenAI and Gemini.
4. App shows both estimates and one reconciled estimate.
5. User accepts or corrects the estimate.

### Weekly Review

1. User takes optional front, side, and back photos in the morning under consistent conditions.
2. App checks photo quality and asks for a retake when pose, framing, or lighting is unsuitable.
3. AI compares the check-in with prior weeks and estimates a body-fat range with confidence, never an exact measurement.
4. App combines visual evidence with weight trend, HealthKit data, meal adherence, workout consistency, and sleep.
5. App recalculates the timeline to 12% and explains what changed.
6. User can correct or reject the AI estimate and receives a practical next-week action plan.

## 7. Success Metrics

- User logs at least 2 meals per day.
- User completes daily check-in at least 5 days per week.
- User reviews weekly projection at least once per week.
- User completes a standardized progress-photo check-in at least three times per month.
- User completes planned training sessions and records enough set data to calculate progression.
- User corrects inaccurate meal estimates instead of abandoning logging.
- App can explain timeline changes in plain language.

## 8. AI Behavior Requirements

- Always call both OpenAI and Gemini for meal analysis and chat in the MVP.
- Show a combined answer first, then provider-specific outputs.
- Use calorie ranges, not false precision.
- Ask for missing portion context when confidence is low.
- Warn that estimates can be wrong.
- Treat photo-based body-fat estimates as broad ranges and label them as non-clinical visual estimates.
- Prefer change over time under consistent photo conditions over claims about absolute body-fat percentage.
- Do not infer identity, ethnicity, medical conditions, attractiveness, or other unrelated sensitive traits from progress photos.
- Avoid medical diagnosis, extreme calorie cuts, unsafe supplement advice, or eating-disorder reinforcement.
- Never change the active training routine directly from chat; return a structured proposal that requires confirmation.
- Use rep ranges and effort targets instead of pretending one exact load fits every session.
- Ask about experience, equipment, injuries, pain, and swimming intensity before making material programming changes.
- Stop or redirect when the user reports sharp pain, neurological symptoms, chest pain, fainting, or other urgent warning signs.

## 9. Privacy Requirements

- API keys must never be stored in the iOS app.
- Passwords must be salted and hashed; raw passwords and raw session tokens must never be stored in the backend database.
- Each backend record must be scoped to the authenticated user, and account switching must not expose another user's local data.
- The iOS app stores only an opaque account session in Keychain and never asks users to enter a server credential.
- Meal and progress photos must be transient analysis inputs and never retained in BodyCompass history or backup.
- Progress-photo upload is optional and requires explicit consent.
- Remove image metadata before upload and allow face-free framing.
- Progress photos must be sent only in the analysis request, never written to app or backend history storage, and discarded from app memory after the result is accepted or rejected.
- HealthKit permissions must be requested clearly and only for needed data.
- User data should not be used for training unless the user explicitly opts in.

## 10. Initial Training Routine

The first user routine to seed in the app is:

| Day | Planned training |
| --- | --- |
| Monday | Chest + triceps |
| Tuesday | Back + biceps, then swimming |
| Wednesday | Legs |
| Thursday | Swimming |
| Friday | Upper body |
| Saturday | Arms, then swimming |
| Sunday | Swimming |

The app should treat this as an editable starting plan, not a permanent prescription. Because it contains five strength sessions and four swimming sessions with no full rest day, Coach should monitor fatigue, soreness, sleep, performance, and adherence and may propose recovery changes. No proposal is applied without confirmation.

## 11. MVP Acceptance Criteria

- User can open the app and see the five main tabs.
- User can register, sign in, relaunch with a validated session, sign out, and delete their account.
- Two accounts cannot read, overwrite, export, or delete one another's records.
- User can calculate a 12% body-fat timeline from profile inputs.
- Backend returns mock AI meal/chat responses without API keys.
- Backend can later use real OpenAI/Gemini keys without changing iOS code.
- HealthKit service exists and is ready for real metric query implementation.
- User can view the current weekly routine and a detailed prescription for each strength session.
- User can manually change the repeating routine or create a one-day exception.
- Coach routine changes remain pending until the user confirms them.
- Docs explain how to run, learn, and continue development.
