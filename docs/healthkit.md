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
