import { readJson } from "../lib/readJson.js";
import { createProjection } from "../services/goalProjection.js";

export async function createGoalProjection(request) {
  const body = await readJson(request);
  return {
    status: 200,
    body: createProjection(body)
  };
}
