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

## 5. MVP Scope

### Must Have

- Native iOS SwiftUI app.
- Apple HealthKit read access for weight, body fat, steps, active energy, workouts, sleep, and resting heart rate.
- Manual fallback entries for missing HealthKit data.
- 12% body-fat projection engine.
- Today dashboard with schedule, calories, protein, activity, sleep, and next best action.
- Meal logging with photo/context input.
- Backend endpoint that sends meal analysis to both OpenAI and Gemini.
- Reconciled calorie/macro estimate with confidence and warnings.
- Coach chat with combined answer and separate provider outputs.
- Weekly review and history screen.
- Standardized weekly morning progress-photo check-in.
- AI visual progress comparison with a body-fat range, confidence, and corrective suggestions.
- Beginner-friendly setup and learning docs.

### Should Have

- User correction flow for meal estimates.
- Weekly projection recalculation from real trend data.
- Simple local notifications for schedule reminders.
- Privacy controls for deleting meal images and logs.

### Out of Scope for MVP

- App Store release.
- Android app.
- Paid subscriptions.
- Full nutrition database integration.
- Wearable-specific workout coaching.
- Medical diagnosis or treatment advice.

## 6. Key User Flows

### Onboarding

1. User enters age, height, weight, current body-fat estimate, and target body fat.
2. App explains that 12% timeline is an estimate.
3. User grants HealthKit permission or chooses manual mode.
4. App calculates starting projection.

### Daily Check-In

1. User opens Today screen.
2. App refreshes HealthKit data.
3. User sees progress against calories, protein, steps, workout, sleep, and schedule.
4. App gives one next best action.

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

## 9. Privacy Requirements

- API keys must never be stored in the iOS app.
- Health data, meal images, and progress photos must be deletable.
- Progress-photo upload is optional and requires explicit consent.
- Remove image metadata before upload and allow face-free framing.
- Progress photos must use private object storage with short-lived access URLs and a configurable retention policy.
- HealthKit permissions must be requested clearly and only for needed data.
- User data should not be used for training unless the user explicitly opts in.

## 10. MVP Acceptance Criteria

- User can open the app and see the five main tabs.
- User can calculate a 12% body-fat timeline from profile inputs.
- Backend returns mock AI meal/chat responses without API keys.
- Backend can later use real OpenAI/Gemini keys without changing iOS code.
- HealthKit service exists and is ready for real metric query implementation.
- Docs explain how to run, learn, and continue development.
