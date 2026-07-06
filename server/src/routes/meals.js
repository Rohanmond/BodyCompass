import { readJson } from "../lib/readJson.js";
import { analyzeMealWithProviders } from "../services/aiProviders.js";

export async function analyzeMeal(request) {
  const body = await readJson(request);

  if (!body.notes && !body.imageBase64) {
    return {
      status: 400,
      body: { error: "Provide meal notes or imageBase64" }
    };
  }

  return {
    status: 200,
    body: await analyzeMealWithProviders(body)
  };
}
