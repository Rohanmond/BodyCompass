export function createProjection(profile) {
  const weightKg = Number(profile.weightKg);
  const bodyFatPercentage = Number(profile.bodyFatPercentage);
  const targetBodyFatPercentage = Number(profile.targetBodyFatPercentage ?? 12);
  const adherenceScore = clamp(Number(profile.adherenceScore ?? 0.75), 0.35, 1);

  if (!Number.isFinite(weightKg) || weightKg <= 0) {
    throw new Error("weightKg must be a positive number");
  }

  if (!Number.isFinite(bodyFatPercentage) || bodyFatPercentage <= 0 || bodyFatPercentage >= 70) {
    throw new Error("bodyFatPercentage must be between 0 and 70");
  }

  if (bodyFatPercentage <= targetBodyFatPercentage) {
    return {
      currentFatMassKg: round(weightKg * bodyFatPercentage / 100),
      currentLeanMassKg: round(weightKg * (1 - bodyFatPercentage / 100)),
      targetWeightKg: round(weightKg),
      fatToLoseKg: 0,
      optimumWeeks: 0,
      aggressiveWeeks: 0,
      conservativeWeeks: 0,
      weeklyLossTargetKg: 0,
      dailyDeficitKcal: 0,
      status: "alreadyAtGoal",
      explanation: "You are already at or below target. Focus on maintenance and performance."
    };
  }

  const currentFatMassKg = weightKg * bodyFatPercentage / 100;
  const currentLeanMassKg = weightKg - currentFatMassKg;
  const targetWeightKg = currentLeanMassKg / (1 - targetBodyFatPercentage / 100);
  const fatToLoseKg = Math.max(0, weightKg - targetWeightKg);
  const baseWeeklyLossKg = clamp(weightKg * 0.0075, 0.35, 0.85);
  const observedTrendKg = profile.weeklyWeightTrendKg == null ? null : Math.abs(Number(profile.weeklyWeightTrendKg));
  const weeklyLossTargetKg = Math.max(0.25, Math.min(observedTrendKg ?? baseWeeklyLossKg, baseWeeklyLossKg) * adherenceScore);
  const dailyDeficitKcal = Math.round(weeklyLossTargetKg * 7700 / 7);

  return {
    currentFatMassKg: round(currentFatMassKg),
    currentLeanMassKg: round(currentLeanMassKg),
    targetWeightKg: round(targetWeightKg),
    fatToLoseKg: round(fatToLoseKg),
    optimumWeeks: Math.ceil(fatToLoseKg / weeklyLossTargetKg),
    aggressiveWeeks: Math.ceil(fatToLoseKg / Math.min(weightKg * 0.01, 1)),
    conservativeWeeks: Math.ceil(fatToLoseKg / Math.max(weightKg * 0.005, 0.25)),
    weeklyLossTargetKg: round(weeklyLossTargetKg),
    dailyDeficitKcal,
    status: adherenceScore < 0.65 ? "needsBetterAdherence" : "onTrack",
    explanation: "Projection assumes lean mass is mostly preserved through protein, strength training, sleep, and a moderate deficit."
  };
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function round(value) {
  return Math.round(value * 10) / 10;
}
