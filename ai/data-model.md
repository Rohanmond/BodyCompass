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

## Design Rule

Every AI estimate should be correctable by the user. Corrected values should be stored separately from original provider outputs.
