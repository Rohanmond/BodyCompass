import { readJson } from "../lib/readJson.js";
import { analyzeMealWithProviders } from "../services/aiProviders.js";
import { consumeAIQuota } from "../lib/aiQuota.js";

export async function analyzeMeal(request) {
  const body = await readJson(request, 12_000_000);

  if (!body.notes && !body.imageBase64) {
    return {
      status: 400,
      body: { error: "Provide meal notes or imageBase64" }
    };
  }

  if (body.imageBase64) {
    const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
    if (!allowedTypes.has(body.imageMimeType)) {
      return {
        status: 415,
        body: { error: "imageMimeType must be image/jpeg, image/png, or image/webp" }
      };
    }

    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(body.imageBase64)) {
      return { status: 400, body: { error: "imageBase64 is not valid base64" } };
    }

    if (Buffer.byteLength(body.imageBase64, "base64") > 8_000_000) {
      return { status: 413, body: { error: "Meal image must be 8 MB or smaller" } };
    }
  }

  const quotaResponse = consumeAIQuota(request, "meal");
  if (quotaResponse) return quotaResponse;

  try {
    return {
      status: 200,
      body: await analyzeMealWithProviders(body)
    };
  } catch (error) {
    return {
      status: 502,
      body: {
        error: "Meal analysis providers are unavailable",
        detail: error instanceof Error ? error.message : "Unknown provider error"
      }
    };
  }
}
