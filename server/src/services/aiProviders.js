export async function analyzeMealWithProviders(payload) {
  const [openai, gemini] = await Promise.all([
    callOpenAI("meal", payload).catch(providerError("openai")),
    callGemini("meal", payload).catch(providerError("gemini"))
  ]);

  return {
    openai,
    gemini,
    reconciled: reconcileMeal(openai, gemini)
  };
}

export async function chatWithProviders(payload) {
  const [openai, gemini] = await Promise.all([
    callOpenAI("chat", payload).catch(providerError("openai")),
    callGemini("chat", payload).catch(providerError("gemini"))
  ]);

  return {
    combined: combineCoachAnswers(openai, gemini),
    openai,
    gemini
  };
}

async function callOpenAI(kind, payload) {
  if (!process.env.OPENAI_API_KEY) {
    return mockProvider("openai", kind, payload);
  }

  // Real provider wiring belongs here. Keep the API key server-side only.
  return mockProvider("openai", kind, payload, "configured");
}

async function callGemini(kind, payload) {
  if (!process.env.GEMINI_API_KEY) {
    return mockProvider("gemini", kind, payload);
  }

  return mockProvider("gemini", kind, payload, "configured");
}

function mockProvider(provider, kind, payload, mode = "mock") {
  if (kind === "meal") {
    return {
      provider,
      mode,
      caloriesRange: [620, 780],
      proteinGrams: 42,
      carbsGrams: 86,
      fatGrams: 22,
      confidence: 0.68,
      likelyMistakes: ["Confirm cooking oil", "Confirm portion size"],
      recommendation: `Based on ${provider}, this meal can fit the cut if protein stays high and oil is controlled.`
    };
  }

  return {
    provider,
    mode,
    answer: `For "${payload.message}", stay with the plan: protein first, complete today's activity, and judge progress from weekly trends instead of one day.`
  };
}

function reconcileMeal(openai, gemini) {
  const openaiCalories = average(openai.caloriesRange);
  const geminiCalories = average(gemini.caloriesRange);
  const midpoint = Math.round((openaiCalories + geminiCalories) / 2);
  const spread = Math.max(80, Math.round(Math.abs(openaiCalories - geminiCalories) / 2) + 70);

  return {
    caloriesRange: [midpoint - spread, midpoint + spread],
    proteinGrams: Math.round((openai.proteinGrams + gemini.proteinGrams) / 2),
    carbsGrams: Math.round((openai.carbsGrams + gemini.carbsGrams) / 2),
    fatGrams: Math.round((openai.fatGrams + gemini.fatGrams) / 2),
    confidence: Math.min(openai.confidence, gemini.confidence),
    likelyMistakes: [...new Set([...openai.likelyMistakes, ...gemini.likelyMistakes])],
    recommendation: "Use this as an estimate, then correct calories if you know exact portions."
  };
}

function combineCoachAnswers(openai, gemini) {
  return [
    "Combined coaching answer:",
    openai.answer,
    gemini.answer,
    "If the two providers disagree, follow the more conservative nutrition estimate and review your weekly trend."
  ].join(" ");
}

function average(range) {
  return (range[0] + range[1]) / 2;
}

function providerError(provider) {
  return (error) => ({
    provider,
    mode: "error",
    error: error instanceof Error ? error.message : "Unknown provider error"
  });
}
