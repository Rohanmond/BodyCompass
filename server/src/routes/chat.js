import { readJson } from "../lib/readJson.js";
import { chatWithProviders, classifyCoachSafety } from "../services/aiProviders.js";
import { persistenceStore } from "../persistence/database.js";

export async function createChatAnswer(request) {
  const body = await readJson(request, 500_000);

  if (typeof body.message !== "string" || !body.message.trim()) {
    return {
      status: 400,
      body: { error: "message is required" }
    };
  }

  if (body.message.length > 2_000) {
    return { status: 413, body: { error: "message must be 2,000 characters or shorter" } };
  }

  try {
    const answer = await chatWithProviders({
      ...body,
      message: body.message.trim(),
      safetyCategory: classifyCoachSafety(body.message)
    });
    if (request.bodyCompassAuth?.userId) {
      persistenceStore().saveChat(
        request.bodyCompassAuth.userId,
        { ...body, message: body.message.trim() },
        answer
      );
    }
    return {
      status: 200,
      body: answer
    };
  } catch (error) {
    return {
      status: 502,
      body: {
        error: "Coach providers are unavailable",
        detail: error instanceof Error ? error.message : "Unknown provider error"
      }
    };
  }
}
