import { readJson } from "../lib/readJson.js";
import { chatWithProviders } from "../services/aiProviders.js";

export async function createChatAnswer(request) {
  const body = await readJson(request);

  if (!body.message) {
    return {
      status: 400,
      body: { error: "message is required" }
    };
  }

  return {
    status: 200,
    body: await chatWithProviders(body)
  };
}
