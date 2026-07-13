# HealthKit Integration

Requested read types:

- Body mass
- Body fat percentage
- Active energy burned
- Step count
- Workouts
- Sleep analysis
- Resting heart rate

BodyCompass should continue working if a user denies HealthKit access or grants only partial access. Manual entries should be clearly labeled and can override imported values for goal calculations.

Daily sync should be opportunistic. iOS background execution is not guaranteed, so the Today screen should refresh HealthKit data when opened.

## Current Implementation

- Permission request and request-status handling are implemented.
- Daily totals are queried for steps, active energy, and workout minutes.
- The most recent weight, body-fat, and resting-heart-rate samples are queried with bounded look-back windows.
- Last-night sleep is queried from the prior evening through the current day.
- Each metric is queried independently so missing or denied data does not block other values.
- Manual weight, body-fat, and sleep values persist for the day and override imported values.
- The Today screen refreshes on open and with pull-to-refresh.

Build verification succeeds for the iOS Simulator. Apple Health permission behavior, partial access, and real readings still require a signed iPhone test because simulator compilation does not validate real HealthKit data.
