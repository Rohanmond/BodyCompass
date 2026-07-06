# BodyCompass Product Notes

BodyCompass is built for a focused fat-loss phase. The app helps the user answer three questions every day:

1. Am I on pace for 12% body fat?
2. Where did today go wrong or right?
3. What is the next useful action?

The app is coaching software, not medical care. It should avoid diagnosing medical conditions, treating eating disorders, or prescribing unsafe deficits.

## Primary User Loop

1. Sync HealthKit and show today's body/activity/sleep context.
2. Log meals with photos and quick portion notes.
3. Compare OpenAI and Gemini meal estimates.
4. Reconcile the estimate, allow user correction, and update adherence.
5. Review daily next action and weekly timeline projection.

## MVP Success Criteria

- The user can see a realistic timeline to 12% body fat.
- The app can explain why the timeline changed.
- Meal estimates show ranges and confidence, not false precision.
- HealthKit failure or missing data does not block manual tracking.
- API keys never ship in the iOS app.
