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
    combined: reconcileCoachAnswers(openai, gemini, payload.safetyCategory),
    openai,
    gemini
  };
}

export async function analyzeProgressWithProviders(payload) {
  const [openai, gemini] = await Promise.all([
    callOpenAI("progress", payload).catch(providerError("openai")),
    callGemini("progress", payload).catch(providerError("gemini"))
  ]);
  return { openai, gemini, reconciled: reconcileProgress(openai, gemini) };
}

async function callOpenAI(kind, payload) {
  if (!process.env.OPENAI_API_KEY) {
    return mockProvider("openai", kind, payload);
  }

  if (kind === "chat") {
    return callOpenAIChat(payload);
  }

  if (kind === "progress") return callOpenAIProgress(payload);

  const response = await fetchWithRetry("https://api.openai.com/v1/responses", {
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

  if (kind === "chat") {
    return callGeminiChat(payload);
  }

  if (kind === "progress") return callGeminiProgress(payload);

  const model = encodeURIComponent(process.env.GEMINI_MODEL ?? "gemini-3.1-flash-lite");
  const response = await fetchWithRetry(
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
      recommendation: `Based on ${provider}, this meal can fit the cut if protein stays high and oil is controlled.`,
      greenSigns: ["Contains a meaningful protein serving", "Includes a balanced carbohydrate source"],
      redFlags: ["Hidden oil or sauce could materially raise calories"],
      improvements: ["Measure added oil", "Add vegetables or fruit for volume and fiber"],
      nextAction: "Keep the protein portion, halve calorie-dense sauce, and log the corrected serving."
    };
  }

  if (kind === "progress") {
    const currentBodyFat = Number(payload.context?.currentBodyFatPercentage) || 20;
    return {
      provider,
      mode,
      bodyFatRange: [Math.max(5, currentBodyFat - 2), Math.min(45, currentBodyFat + 2)],
      confidence: 0.55,
      imageQuality: "limited",
      visibleChanges: ["Current visual baseline recorded without retaining the photos"],
      limitations: ["Photo estimates vary with lighting, posture, hydration, and camera distance"],
      suggestions: ["Keep capture conditions consistent next week", "Use weight trend alongside the visual range"],
      nextWeekAction: "Hold the current plan for one week and compare the trend under the same conditions.",
      positiveSignals: ["All three standardized angles were supplied"],
      warningSignals: ["Visual body-fat estimates remain sensitive to lighting, posture, and hydration"]
    };
  }

  const wantsRoutineChange = /\b(change|adjust|update|review|reduce)\b.*\b(routine|workout|training|swim)/i.test(payload.message);
  return {
    provider,
    mode,
    answer: safeMockCoachAnswer(payload),
    nextAction: payload.safetyCategory === "normal"
      ? "Complete the highest-priority unfinished item in today's schedule."
      : "Pause the plan change and follow the safety guidance above.",
    safetyNotice: payload.safetyCategory === "normal" ? "" : safetyGuidance(payload.safetyCategory),
    routineProposal: wantsRoutineChange && payload.safetyCategory === "normal"
      ? mockRoutineProposal()
      : null
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
      recommendation: `${estimate.recommendation} Review portions because only one provider responded.`,
      greenSigns: estimate.greenSigns ?? [],
      redFlags: uniqueLimited([...(estimate.redFlags ?? []), "Only one AI provider responded"], 4),
      improvements: estimate.improvements ?? [],
      nextAction: estimate.nextAction ?? "Verify the portion and adjust the next meal if needed."
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
    recommendation: "Use this estimate to make one practical adjustment, then correct calories if you know exact portions.",
    greenSigns: uniqueLimited([...(openai.greenSigns ?? []), ...(gemini.greenSigns ?? [])], 4),
    redFlags: uniqueLimited([...(openai.redFlags ?? []), ...(gemini.redFlags ?? [])], 4),
    improvements: uniqueLimited([...(openai.improvements ?? []), ...(gemini.improvements ?? [])], 4),
    nextAction: openai.nextAction === gemini.nextAction
      ? openai.nextAction
      : (openai.nextAction || gemini.nextAction || "Use the estimate to plan the rest of today's meals.")
  };
}

function reconcileCoachAnswers(openai, gemini, safetyCategory = "normal") {
  const successful = [openai, gemini].filter((result) => result.mode !== "error");
  if (successful.length === 0) throw new Error("Both OpenAI and Gemini failed to answer");

  const primary = successful[0];
  const secondary = successful[1];
  const proposals = successful
    .map((result) => result.routineProposal)
    .filter(Boolean)
    .sort((a, b) => a.changes.length - b.changes.length);

  return {
    answer: secondary && secondary.answer !== primary.answer
      ? `${primary.answer}\n\nSecond-provider check: ${secondary.answer}`
      : primary.answer,
    nextAction: primary.nextAction,
    safetyNotice: safetyCategory === "normal"
      ? (primary.safetyNotice || secondary?.safetyNotice || "")
      : safetyGuidance(safetyCategory),
    routineProposal: safetyCategory === "normal" ? (proposals[0] ?? null) : null,
    confidence: successful.length === 2 ? "dual_provider" : "single_provider"
  };
}

function reconcileProgress(openai, gemini) {
  const successful = [openai, gemini].filter((result) => result.mode !== "error");
  if (successful.length === 0) throw new Error("Both OpenAI and Gemini failed to analyze progress");
  if (successful.length === 1) {
    const estimate = successful[0];
    const { provider: _provider, mode: _mode, ...result } = estimate;
    return {
      ...result,
      confidence: Math.min(estimate.confidence, 0.5),
      limitations: [...estimate.limitations, "Only one provider returned an estimate"],
      positiveSignals: estimate.positiveSignals ?? [],
      warningSignals: uniqueLimited([...(estimate.warningSignals ?? []), "Only one AI provider responded"], 4)
    };
  }

  const lower = Math.max(3, Math.floor((openai.bodyFatRange[0] + gemini.bodyFatRange[0]) / 2 - 1));
  const upper = Math.min(60, Math.ceil((openai.bodyFatRange[1] + gemini.bodyFatRange[1]) / 2 + 1));
  const qualityOrder = { good: 0, limited: 1, unsuitable: 2 };
  const quality = qualityOrder[openai.imageQuality] >= qualityOrder[gemini.imageQuality]
    ? openai.imageQuality
    : gemini.imageQuality;
  return {
    bodyFatRange: [lower, upper],
    confidence: Math.min(openai.confidence, gemini.confidence),
    imageQuality: quality,
    visibleChanges: uniqueLimited([...openai.visibleChanges, ...gemini.visibleChanges], 6),
    limitations: uniqueLimited([...openai.limitations, ...gemini.limitations], 6),
    suggestions: uniqueLimited([...openai.suggestions, ...gemini.suggestions], 5),
    positiveSignals: uniqueLimited([...(openai.positiveSignals ?? []), ...(gemini.positiveSignals ?? [])], 4),
    warningSignals: uniqueLimited([...(openai.warningSignals ?? []), ...(gemini.warningSignals ?? [])], 4),
    nextWeekAction: openai.nextWeekAction === gemini.nextWeekAction
      ? openai.nextWeekAction
      : `${openai.nextWeekAction} Cross-check: ${gemini.nextWeekAction}`
  };
}

function average(range) {
  return (range[0] + range[1]) / 2;
}

function uniqueLimited(values, maximum) {
  return [...new Set(values.map((value) => String(value).trim()).filter(Boolean))].slice(0, maximum);
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
    recommendation: { type: "string" },
    greenSigns: { type: "array", items: { type: "string" }, maxItems: 4 },
    redFlags: { type: "array", items: { type: "string" }, maxItems: 4 },
    improvements: { type: "array", items: { type: "string" }, maxItems: 4 },
    nextAction: { type: "string" }
  },
  required: [
    "title", "caloriesRange", "proteinGrams", "carbsGrams", "fatGrams",
    "confidence", "likelyMistakes", "recommendation", "greenSigns",
    "redFlags", "improvements", "nextAction"
  ]
};

const progressSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    bodyFatRange: {
      type: "array",
      items: { type: "number", minimum: 3, maximum: 60 },
      minItems: 2,
      maxItems: 2,
      description: "A broad, non-clinical visual body-fat percentage range"
    },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    imageQuality: { type: "string", enum: ["good", "limited", "unsuitable"] },
    visibleChanges: { type: "array", items: { type: "string" }, maxItems: 6 },
    limitations: { type: "array", items: { type: "string" }, maxItems: 6 },
    suggestions: { type: "array", items: { type: "string" }, maxItems: 5 },
    nextWeekAction: { type: "string" },
    positiveSignals: { type: "array", items: { type: "string" }, maxItems: 4 },
    warningSignals: { type: "array", items: { type: "string" }, maxItems: 4 }
  },
  required: [
    "bodyFatRange", "confidence", "imageQuality", "visibleChanges",
    "limitations", "suggestions", "nextWeekAction", "positiveSignals", "warningSignals"
  ]
};

function mealInputParts(payload, provider) {
  const context = payload.context ?? {};
  const prompt = [
    "Estimate this meal for a fat-loss food log. Be conservative about hidden oil, sauces, and portion size.",
    "This is an estimate, not medical advice. Do not identify people or infer health conditions.",
    `User notes: ${payload.notes?.trim() || "None"}`,
    `Context: target calories ${context.targetCalories ?? "unknown"}, target protein ${context.targetProteinGrams ?? "unknown"}g.`,
    "Explain what the calorie estimate means for the user's fat-loss goal.",
    "Green signs should identify useful protein, fiber, produce, portion balance, or preparation choices actually visible or stated.",
    "Red flags should identify actionable issues such as low protein, hidden fats/sauces, sugary drinks, low produce/fiber, very large portions, or major uncertainty. Do not moralize food.",
    "Improvements must say what to reduce, swap, add, or measure. End with one specific next action for this meal or the rest of today.",
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

async function callOpenAIProgress(payload) {
  const response = await fetchWithRetry("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL ?? "gpt-5.4",
      input: [{ role: "user", content: progressInputParts(payload, "openai") }],
      text: {
        format: {
          type: "json_schema",
          name: "progress_analysis",
          strict: true,
          schema: progressSchema
        }
      }
    })
  });
  const result = await parseProviderResponse(response, "OpenAI");
  const outputText = result.output_text ?? result.output
    ?.flatMap((item) => item.content ?? [])
    .find((item) => item.type === "output_text")?.text;
  return normalizeProgressResult("openai", JSON.parse(outputText));
}

async function callGeminiProgress(payload) {
  const model = encodeURIComponent(process.env.GEMINI_MODEL ?? "gemini-3.1-flash-lite");
  const response = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": process.env.GEMINI_API_KEY,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: progressInputParts(payload, "gemini") }],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: progressSchema
        }
      })
    }
  );
  const result = await parseProviderResponse(response, "Gemini");
  const outputText = result.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? "").join("");
  return normalizeProgressResult("gemini", JSON.parse(outputText));
}

function progressInputParts(payload, provider) {
  const context = JSON.stringify(payload.context ?? {}).slice(0, 25_000);
  const prompt = [
    "Review standardized weekly physique photos for a non-medical fat-loss progress log.",
    "Return a broad visual body-fat percentage range, never an exact measurement or diagnosis.",
    "Do not identify the person, judge attractiveness, or infer unrelated sensitive traits.",
    "Treat lighting, pose, hydration, camera angle, and distance as meaningful limitations.",
    "Do not claim visual week-over-week change because prior photos are not retained; use saved range and health trends only as context.",
    "Return positive signals as cautious, observable signs that support progress or a reliable check-in.",
    "Return warning signals for poor comparability, adverse trend context, or reasons not to trust the estimate; never judge appearance.",
    "If framing or quality is inadequate, mark imageQuality unsuitable, lower confidence, and explain why.",
    `User trend context JSON: ${context}`,
    "Current photos follow in front, side, back order and must be treated as transient analysis inputs."
  ].join("\n");
  const parts = [provider === "openai" ? { type: "input_text", text: prompt } : { text: prompt }];

  for (const photo of payload.currentPhotos) {
    parts.push(provider === "openai"
      ? {
          type: "input_image",
          image_url: `data:${photo.imageMimeType};base64,${photo.imageBase64}`,
          detail: "high"
        }
      : {
          inline_data: {
            mime_type: photo.imageMimeType,
            data: photo.imageBase64
          }
        });
  }
  return parts;
}

function normalizeProgressResult(provider, result) {
  if (!result || !Array.isArray(result.bodyFatRange) || result.bodyFatRange.length !== 2) {
    throw new Error(`${provider} returned an invalid progress analysis`);
  }
  const range = result.bodyFatRange.map((value) => Math.max(3, Math.min(60, Number(value) || 0)));
  const allowedQualities = new Set(["good", "limited", "unsuitable"]);
  return {
    provider,
    mode: "live",
    bodyFatRange: [Math.min(...range), Math.max(...range)],
    confidence: Math.max(0, Math.min(1, Number(result.confidence) || 0)),
    imageQuality: allowedQualities.has(result.imageQuality) ? result.imageQuality : "limited",
    visibleChanges: uniqueLimited(Array.isArray(result.visibleChanges) ? result.visibleChanges : [], 6),
    limitations: uniqueLimited(Array.isArray(result.limitations) ? result.limitations : [], 6),
    suggestions: uniqueLimited(Array.isArray(result.suggestions) ? result.suggestions : [], 5),
    nextWeekAction: String(result.nextWeekAction || "Repeat the check-in under the same conditions next week."),
    positiveSignals: uniqueLimited(Array.isArray(result.positiveSignals) ? result.positiveSignals : [], 4),
    warningSignals: uniqueLimited(Array.isArray(result.warningSignals) ? result.warningSignals : [], 4)
  };
}

async function parseProviderResponse(response, provider) {
  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${provider} returned ${response.status}: ${result.error?.message ?? "Request failed"}`);
  }
  return result;
}

async function fetchWithRetry(url, options, overrides = {}) {
  const fetchImpl = overrides.fetchImpl ?? fetch;
  const sleep = overrides.sleep ?? ((milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)));
  const attempts = overrides.attempts ?? 3;
  let lastError;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetchImpl(url, options);
      const shouldRetry = response.status === 429 || response.status === 503;
      if (!shouldRetry || attempt === attempts - 1) return response;

      await response.arrayBuffer().catch(() => undefined);
      await sleep(retryDelayMilliseconds(response, attempt));
    } catch (error) {
      lastError = error;
      if (attempt === attempts - 1) throw error;
      await sleep(750 * (2 ** attempt));
    }
  }

  throw lastError ?? new Error("Provider request failed");
}

function retryDelayMilliseconds(response, attempt) {
  const retryAfterSeconds = Number(response.headers.get("retry-after"));
  if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0) {
    return Math.min(retryAfterSeconds * 1_000, 5_000);
  }
  return 750 * (2 ** attempt);
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
    recommendation: String(result.recommendation || "Confirm portions before saving."),
    greenSigns: uniqueLimited(Array.isArray(result.greenSigns) ? result.greenSigns : [], 4),
    redFlags: uniqueLimited(Array.isArray(result.redFlags) ? result.redFlags : [], 4),
    improvements: uniqueLimited(Array.isArray(result.improvements) ? result.improvements : [], 4),
    nextAction: String(result.nextAction || "Verify the portion and use the estimate to plan the rest of today.")
  };
}

function nonNegativeInteger(value) {
  return Math.max(0, Math.round(Number(value) || 0));
}

export const __testing = { reconcileMeal, normalizeMealResult, fetchWithRetry };

const coachSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    answer: { type: "string" },
    nextAction: { type: "string" },
    safetyNotice: { type: "string" },
    routineProposal: {
      type: ["object", "null"],
      additionalProperties: false,
      properties: {
        summary: { type: "string" },
        reasons: { type: "array", items: { type: "string" }, maxItems: 4 },
        expectedBenefit: { type: "string" },
        recoveryImpact: { type: "string" },
        changes: {
          type: "array",
          maxItems: 4,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              weekday: { type: "string", enum: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"] },
              target: { type: "string", enum: ["day", "swim", "exercise"] },
              sessionTitle: { type: "string" },
              exerciseName: { type: "string" },
              action: { type: "string", enum: ["make_rest_day", "update_swim", "update_exercise"] },
              targetMinutes: { type: "integer", minimum: 0, maximum: 180 },
              intensity: { type: "string", enum: ["none", "easy", "moderate", "hard"] },
              workingSets: { type: "integer", minimum: 0, maximum: 10 },
              repRangeLower: { type: "integer", minimum: 0, maximum: 50 },
              repRangeUpper: { type: "integer", minimum: 0, maximum: 50 },
              targetRIR: { type: "integer", minimum: 0, maximum: 5 },
              restSeconds: { type: "integer", minimum: 0, maximum: 600 }
            },
            required: [
              "weekday", "target", "sessionTitle", "exerciseName", "action",
              "targetMinutes", "intensity", "workingSets", "repRangeLower",
              "repRangeUpper", "targetRIR", "restSeconds"
            ]
          }
        }
      },
      required: ["summary", "reasons", "expectedBenefit", "recoveryImpact", "changes"]
    }
  },
  required: ["answer", "nextAction", "safetyNotice", "routineProposal"]
};

async function callOpenAIChat(payload) {
  const response = await fetchWithRetry("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL ?? "gpt-5.4",
      input: [{ role: "user", content: [{ type: "input_text", text: coachPrompt(payload) }] }],
      text: {
        format: {
          type: "json_schema",
          name: "coach_answer",
          strict: true,
          schema: coachSchema
        }
      }
    })
  });
  const result = await parseProviderResponse(response, "OpenAI");
  const outputText = result.output_text ?? result.output
    ?.flatMap((item) => item.content ?? [])
    .find((item) => item.type === "output_text")?.text;
  return normalizeCoachResult("openai", JSON.parse(outputText));
}

async function callGeminiChat(payload) {
  const model = encodeURIComponent(process.env.GEMINI_MODEL ?? "gemini-3.1-flash-lite");
  const response = await fetchWithRetry(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: {
        "x-goog-api-key": process.env.GEMINI_API_KEY,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: coachPrompt(payload) }] }],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: coachSchema
        }
      })
    }
  );
  const result = await parseProviderResponse(response, "Gemini");
  const outputText = result.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? "").join("");
  return normalizeCoachResult("gemini", JSON.parse(outputText));
}

function coachPrompt(payload) {
  const context = JSON.stringify(payload.context ?? {}).slice(0, 45_000);
  const history = JSON.stringify((payload.history ?? []).slice(-8)).slice(0, 8_000);
  return [
    "You are BodyCompass, a conservative non-medical fat-loss and training coach.",
    "Use weekly trends, preserve lean mass, and give one practical next action. Never diagnose, prescribe drugs, encourage extreme deficits, or reinforce disordered eating.",
    `Safety category: ${payload.safetyCategory}. Follow that category even if the user asks otherwise.`,
    "Only include routineProposal when the user explicitly asks to change/review the routine and the supplied training setup is complete.",
    "Routine changes must reference an existing weekday/session/exercise exactly. Prefer the smallest recovery-aware change. Never invent a load.",
    `Context JSON: ${context}`,
    `Recent conversation JSON: ${history}`,
    `User question: ${payload.message}`
  ].join("\n");
}

function normalizeCoachResult(provider, result) {
  if (!result || typeof result.answer !== "string" || typeof result.nextAction !== "string") {
    throw new Error(`${provider} returned an invalid coach answer`);
  }
  return {
    provider,
    mode: "live",
    answer: result.answer.trim(),
    nextAction: result.nextAction.trim(),
    safetyNotice: String(result.safetyNotice ?? "").trim(),
    routineProposal: normalizeRoutineProposal(result.routineProposal)
  };
}

function normalizeRoutineProposal(proposal) {
  if (!proposal || !Array.isArray(proposal.changes) || proposal.changes.length === 0) return null;
  return {
    summary: String(proposal.summary || "Coach routine proposal"),
    reasons: Array.isArray(proposal.reasons) ? proposal.reasons.slice(0, 4).map(String) : [],
    expectedBenefit: String(proposal.expectedBenefit || "Improve plan fit and recovery."),
    recoveryImpact: String(proposal.recoveryImpact || "Review the change before confirming."),
    changes: proposal.changes.slice(0, 4)
  };
}

function safeMockCoachAnswer(payload) {
  if (payload.safetyCategory !== "normal") return safetyGuidance(payload.safetyCategory);
  return `For "${payload.message}", use today's logged data and weekly trend rather than reacting to one measurement. Keep protein high, complete the planned activity if recovery is adequate, and avoid making the calorie deficit more aggressive without a sustained plateau.`;
}

function mockRoutineProposal() {
  return {
    summary: "Reduce Sunday swimming load for recovery",
    reasons: ["The current week has no full rest day", "Sunday directly precedes Monday strength training"],
    expectedBenefit: "Start Monday fresher while keeping swimming consistency.",
    recoveryImpact: "Sunday becomes a shorter easy swim; other sessions stay unchanged.",
    changes: [{
      weekday: "sunday",
      target: "swim",
      sessionTitle: "Swimming",
      exerciseName: "",
      action: "update_swim",
      targetMinutes: 20,
      intensity: "easy",
      workingSets: 0,
      repRangeLower: 0,
      repRangeUpper: 0,
      targetRIR: 0,
      restSeconds: 0
    }]
  };
}

export function classifyCoachSafety(message) {
  const text = String(message).toLowerCase();
  if (/\b(chest pain|can't breathe|cannot breathe|fainted|unconscious|suicid|self[- ]?harm)\b/.test(text)) return "urgent_medical";
  if (/\b(anorexi|bulimi|purge|starve|binge and purge|afraid to eat)\b/.test(text)) return "eating_disorder";
  if (/\b(steroid|trenbolone|clenbuterol|sarms|fat burner drug|diuretic)\b/.test(text)) return "drug_advice";
  if (/\b(500 calories|800 calories|stop eating|zero calorie|lose [0-9]+ ?kg (in|per) (a )?week)\b/.test(text)) return "extreme_deficit";
  if (/\b(sharp pain|injur|swollen|torn|sprain|fracture)\b/.test(text)) return "injury";
  return "normal";
}

function safetyGuidance(category) {
  switch (category) {
    case "urgent_medical": return "Stop training and seek urgent medical help now. Contact local emergency services or a trusted person nearby; this app cannot assess an emergency.";
    case "eating_disorder": return "I cannot help intensify restriction or compensatory exercise. Pause the cut and speak with a qualified clinician or eating-disorder support service.";
    case "drug_advice": return "I cannot recommend performance-enhancing or weight-loss drugs. Discuss risks and safer options with a licensed clinician.";
    case "extreme_deficit": return "That deficit is not a safe coaching target. Use a moderate pace and consult a qualified dietitian or clinician for an individualized plan.";
    case "injury": return "Do not train through sharp or worsening pain. Stop the affected movement and seek assessment from a qualified clinician or physiotherapist.";
    default: return "";
  }
}

export const __chatTesting = { reconcileCoachAnswers, normalizeCoachResult, normalizeRoutineProposal };
export const __progressTesting = { reconcileProgress, normalizeProgressResult };
