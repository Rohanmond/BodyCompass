import { readJson } from "../lib/readJson.js";
import { persistenceStore } from "../persistence/database.js";

export async function saveProfile(request) {
  const body = await readJson(request, 250_000);
  if (typeof body.name !== "string" || !body.name.trim()) return badRequest("name is required");
  return { status: 200, body: persistenceStore().saveProfile(userId(request), body) };
}

export async function saveSchedule(request) {
  const body = await readJson(request, 500_000);
  if (!Array.isArray(body.items) || body.items.length > 200) return badRequest("items must be an array with at most 200 entries");
  return { status: 200, body: persistenceStore().saveSchedule(userId(request), body.items) };
}

export async function saveMealRecord(request) {
  const body = await readJson(request, 1_000_000);
  if ("imageBase64" in body || "imageMimeType" in body) return badRequest("Meal history does not accept photos");
  if (typeof body.id !== "string" || !body.id) return badRequest("id is required");
  if (!body.accepted || typeof body.accepted !== "object") return badRequest("accepted nutrition is required");
  return { status: 201, body: await persistenceStore().saveMeal(userId(request), body) };
}

export async function deleteMealRecord(request) {
  const body = await readJson(request, 10_000);
  if (typeof body.id !== "string" || !body.id) return badRequest("id is required");
  const deleted = await persistenceStore().deleteMeal(userId(request), body.id);
  return deleted ? { status: 204, body: {} } : { status: 404, body: { error: "Meal not found" } };
}

export async function saveProgressRecord(request) {
  const body = await readJson(request, 2_000_000);
  if (typeof body.id !== "string" || !body.id) return badRequest("id is required");
  if (!body.analysis || typeof body.analysis !== "object") return badRequest("analysis is required");
  if ("photos" in body) return badRequest("Progress history does not accept photos");
  return { status: 201, body: await persistenceStore().saveProgressCheckIn(userId(request), body) };
}

export async function deleteProgressRecord(request) {
  const body = await readJson(request, 10_000);
  if (typeof body.id !== "string" || !body.id) return badRequest("id is required");
  const deleted = await persistenceStore().deleteProgressCheckIn(userId(request), body.id);
  return deleted ? { status: 204, body: {} } : { status: 404, body: { error: "Check-in not found" } };
}

export async function exportAccountData(request) {
  return { status: 200, body: await persistenceStore().exportUser(userId(request)) };
}

export async function deleteAccountData(request) {
  const body = await readJson(request, 10_000);
  if (body.confirmation !== "DELETE MY BODYCOMPASS DATA") return badRequest("Exact deletion confirmation is required");
  return { status: 200, body: await persistenceStore().deleteUserData(userId(request)) };
}

function userId(request) { return request.bodyCompassAuth?.userId ?? "local-owner"; }
function badRequest(message) { return { status: 400, body: { error: message } }; }
