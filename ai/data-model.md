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

`TrainingRoutine` (implemented in `BodyCompassCore`, persisted as versions in `UserDefaults`)

- id, version, source (seed, user, coach), changeSummary, createdAt
- days: seven `TrainingDay` values (weekday + sessions)
- `TrainingSession`: title, kind (strength, swimming, recovery), muscleGroups, exercises, swimPlan, notes
- `ExercisePrescription`: name, warmUp, workingSets, repRange, targetRIR, restSeconds, techniqueNotes, substitutions — never a starting load

`TrainingDayException` — date key, replacement sessions (empty = rest), note; applied on top of the routine without mutating it

`ExerciseSetLog` / `SwimSessionLog` — logged load/reps/RIR/pain and duration/distance/intensity per date

`RoutineChangeProposal` — baseVersion, proposedDays, reasons, expectedBenefit, recoveryImpact, status (pending, confirmed, rejected); only explicit confirmation creates a new routine version

`TrainingSetup` — experience, equipment, limitations, swim minutes/intensity; collected before detailed prescriptions are generated

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

`training_routines`

- id and userId
- version and status (active, proposed, archived)
- effective date
- optional end date for temporary versions
- source (user, coach proposal)
- change rationale and recovery impact
- createdAt and confirmedAt
- parent routine version for history and rollback

`training_day_exceptions`

- userId and date
- source training day
- replacement or skipped session
- reason or note

`training_days`

- routineId
- weekday and order
- title and session type (strength, swimming, recovery)
- muscle groups
- notes

`exercise_prescriptions`

- trainingDayId
- exercise name and order
- warm-up instructions
- working sets and rep range
- target RIR or RPE
- rest seconds
- progression rule
- substitutions

`workout_logs`

- userId and trainingDayId
- performedAt
- exercise, set, load, reps, and actual RIR/RPE
- pain or limitation note
- swimming duration, distance, and intensity when applicable

`routine_change_proposals`

- currentRoutineId and proposedRoutineId
- originating coach message
- structured before/after changes
- reasons, expected benefit, and recovery impact
- status (pending, confirmed, edited, rejected)
- user decision timestamp

`watch_workout_sync`

- workout/session UUID shared across Watch and iPhone
- routine and training-day version identifiers
- WorkoutKit schedule/open state and selected swimming location
- origin device and sync revision for BodyCompass logs
- queued set/swim log identifiers
- HealthKit workout UUID after save
- imported duration, active energy, and swimming distance
- sync status, conflict state, and retry metadata

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
