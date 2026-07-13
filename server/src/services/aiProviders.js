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

  if (kind !== "meal") {
    return mockProvider("openai", kind, payload, "configured-mock");
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL ?? "gpt-5.4",
      input: [{
        role: "user",
        content: mealInputParts(payload, "openai")
      }],
      text: {
        format: {
          type: "json_schema",
          name: "meal_analysis",
          strict: true,
          schema: mealSchema
        }
      }
    })
  });

  const result = await parseProviderResponse(response, "OpenAI");
  const outputText = result.output_text ?? result.output
    ?.flatMap((item) => item.content ?? [])
    .find((item) => item.type === "output_text")?.text;
  return normalizeMealResult("openai", JSON.parse(outputText));
}

async function callGemini(kind, payload) {
  if (!process.env.GEMINI_API_KEY) {
    return mockProvider("gemini", kind, payload);
  }

  if (kind !== "meal") {
    return mockProvider("gemini", kind, payload, "configured-mock");
  }

  const model = encodeURIComponent(process.env.GEMINI_MODEL ?? "gemini-2.5-pro");
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": process.env.GEMINI_API_KEY,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: mealInputParts(payload, "gemini") }],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: mealSchema
        }
      })
    }
  );

  const result = await parseProviderResponse(response, "Gemini");
  const outputText = result.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? "").join("");
  return normalizeMealResult("gemini", JSON.parse(outputText));
}

function mockProvider(provider, kind, payload, mode = "mock") {
  if (kind === "meal") {
    return {
      provider,
      mode,
      title: payload.notes?.trim() || "Meal estimate",
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
  const successful = [openai, gemini].filter((result) => result.mode !== "error");
  if (successful.length === 0) {
    throw new Error("Both OpenAI and Gemini failed to analyze the meal");
  }

  if (successful.length === 1) {
    const estimate = successful[0];
    const missing = estimate.provider === "openai" ? "Gemini" : "OpenAI";
    return {
      title: estimate.title,
      caloriesRange: estimate.caloriesRange,
      proteinGrams: estimate.proteinGrams,
      carbsGrams: estimate.carbsGrams,
      fatGrams: estimate.fatGrams,
      confidence: Math.min(estimate.confidence, 0.55),
      likelyMistakes: [...estimate.likelyMistakes, `${missing} estimate unavailable`],
      recommendation: `${estimate.recommendation} Review portions because only one provider responded.`
    };
  }

  const openaiCalories = average(openai.caloriesRange);
  const geminiCalories = average(gemini.caloriesRange);
  const midpoint = Math.round((openaiCalories + geminiCalories) / 2);
  const spread = Math.max(80, Math.round(Math.abs(openaiCalories - geminiCalories) / 2) + 70);

  return {
    title: openai.title === gemini.title ? openai.title : `${openai.title} / ${gemini.title}`,
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

const mealSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string", description: "Short name for the visible meal" },
    caloriesRange: {
      type: "array",
      items: { type: "integer" },
      minItems: 2,
      maxItems: 2,
      description: "Conservative lower and upper calorie estimate"
    },
    proteinGrams: { type: "integer", minimum: 0 },
    carbsGrams: { type: "integer", minimum: 0 },
    fatGrams: { type: "integer", minimum: 0 },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    likelyMistakes: { type: "array", items: { type: "string" }, maxItems: 4 },
    recommendation: { type: "string" }
  },
  required: [
    "title", "caloriesRange", "proteinGrams", "carbsGrams", "fatGrams",
    "confidence", "likelyMistakes", "recommendation"
  ]
};

function mealInputParts(payload, provider) {
  const context = payload.context ?? {};
  const prompt = [
    "Estimate this meal for a fat-loss food log. Be conservative about hidden oil, sauces, and portion size.",
    "This is an estimate, not medical advice. Do not identify people or infer health conditions.",
    `User notes: ${payload.notes?.trim() || "None"}`,
    `Context: target calories ${context.targetCalories ?? "unknown"}, target protein ${context.targetProteinGrams ?? "unknown"}g.`,
    "Return only the requested structured nutrition result."
  ].join("\n");

  const textPart = provider === "openai"
    ? { type: "input_text", text: prompt }
    : { text: prompt };
  if (!payload.imageBase64) return [textPart];

  const imagePart = provider === "openai"
    ? {
        type: "input_image",
        image_url: `data:${payload.imageMimeType};base64,${payload.imageBase64}`,
        detail: "high"
      }
    : {
        inline_data: {
          mime_type: payload.imageMimeType,
          data: payload.imageBase64
        }
      };
  return [textPart, imagePart];
}

async function parseProviderResponse(response, provider) {
  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${provider} returned ${response.status}: ${result.error?.message ?? "Request failed"}`);
  }
  return result;
}

function normalizeMealResult(provider, result) {
  if (!result || !Array.isArray(result.caloriesRange) || result.caloriesRange.length !== 2) {
    throw new Error(`${provider} returned an invalid meal analysis`);
  }

  const calories = result.caloriesRange.map((value) => Math.max(0, Math.round(Number(value))));
  return {
    provider,
    mode: "live",
    title: String(result.title || "Meal estimate"),
    caloriesRange: [Math.min(...calories), Math.max(...calories)],
    proteinGrams: nonNegativeInteger(result.proteinGrams),
    carbsGrams: nonNegativeInteger(result.carbsGrams),
    fatGrams: nonNegativeInteger(result.fatGrams),
    confidence: Math.max(0, Math.min(1, Number(result.confidence) || 0)),
    likelyMistakes: Array.isArray(result.likelyMistakes)
      ? result.likelyMistakes.slice(0, 4).map(String)
      : [],
    recommendation: String(result.recommendation || "Confirm portions before saving.")
  };
}

function nonNegativeInteger(value) {
  return Math.max(0, Math.round(Number(value) || 0));
}

export const __testing = { reconcileMeal, normalizeMealResult };
