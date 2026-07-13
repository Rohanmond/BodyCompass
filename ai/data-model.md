# Data Model

## Current Swift Models

`BodyProfile`

- name
- age
- heightCm
- weightKg
- bodyFatPercentage
- targetBodyFatPercentage
- weeklyWeightTrendKg
- adherenceScore
- workoutTimePreference

`DailyHealthSnapshot`

- date
- weightKg
- bodyFatPercentage
- steps
- activeEnergyKcal
- sleepHours
- restingHeartRate
- workoutMinutes

`MealAnalysis`

- title
- caloriesRange
- proteinGrams
- carbsGrams
- fatGrams
- confidence
- likelyMistakes
- recommendation

## Future Persistent Entities

`users`

- id
- email or local user identifier
- createdAt

`profiles`

- userId
- age
- sex if the user chooses to provide it
- heightCm
- targetBodyFatPercentage
- diet preference
- training schedule preference

`health_snapshots`

- userId
- date
- imported/manual source flags
- weight/body-fat/activity/sleep/workout fields

`meals`

- userId
- date/time
- imageUrl
- notes
- openaiEstimate
- geminiEstimate
- reconciledEstimate
- userCorrectedEstimate

`schedule_items`

- userId
- date
- title
- completion state

`coach_messages`

- userId
- role
- message
- combined response
- provider responses

`progress_check_ins`

- userId
- capturedAt
- measurement conditions (morning, lighting, distance)
- private front/side/back image references
- OpenAI estimate range, confidence, observations, and limitations
- Gemini estimate range, confidence, observations, and limitations
- reconciled estimate range and visible change from prior check-in
- linked weight and health trend context
- user-corrected estimate or rejection
- next-week recommendations

## Design Rule

Every AI estimate should be correctable by the user. Corrected values should be stored separately from original provider outputs.

Photo-based body-fat analysis must store a range and confidence, never promote a single AI-generated number as a measurement, and must remain separate from HealthKit or manually measured body-fat values.
