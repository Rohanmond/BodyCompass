import { readJson } from "../lib/readJson.js";
import { persistenceStore } from "../persistence/database.js";

const allowedImageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

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
  const body = await readJson(request, 12_000_000);
  const imageError = validateImage(body.imageBase64, body.imageMimeType, 8_000_000);
  if (imageError) return imageError;
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
  const body = await readJson(request, 22_000_000);
  if (typeof body.id !== "string" || !body.id) return badRequest("id is required");
  if (!body.analysis || typeof body.analysis !== "object") return badRequest("analysis is required");
  if (!Array.isArray(body.photos) || body.photos.length !== 3) return badRequest("front, side, and back photos are required");
  const poses = new Set();
  for (const photo of body.photos) {
    if (!["front", "side", "back"].includes(photo?.pose) || poses.has(photo.pose)) return badRequest("photos must use unique front, side, and back poses");
    poses.add(photo.pose);
    const imageError = validateImage(photo.imageBase64, photo.imageMimeType, 6_000_000);
    if (imageError) return imageError;
  }
  return { status: 201, body: await persistenceStore().saveProgressCheckIn(userId(request), body) };
}

export async function deleteProgressRecord(request) {
  const body = await readJson(request, 10_000);
  if (typeof body.id !== "string" || !body.id) return badRequest("id is required");
  const deleted = await persistenceStore().deleteProgressCheckIn(userId(request), body.id);
  return deleted ? { status: 204, body: {} } : { status: 404, body: { error: "Check-in not found" } };
}

export async function exportAccountData(request) {
  const includeImages = new URL(request.url ?? "/", "http://localhost").searchParams.get("includeImages") === "true";
  return { status: 200, body: await persistenceStore().exportUser(userId(request), includeImages) };
}

export async function deleteAccountData(request) {
  const body = await readJson(request, 10_000);
  if (body.confirmation !== "DELETE MY BODYCOMPASS DATA") return badRequest("Exact deletion confirmation is required");
  return { status: 200, body: await persistenceStore().deleteUserData(userId(request)) };
}

function validateImage(base64, mimeType, maximumBytes) {
  if (!base64) return null;
  if (!allowedImageTypes.has(mimeType)) return { status: 415, body: { error: "Images must be JPEG, PNG, or WebP" } };
  if (typeof base64 !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(base64)) return badRequest("An image contains invalid base64");
  if (Buffer.byteLength(base64, "base64") > maximumBytes) return { status: 413, body: { error: `Image must be ${maximumBytes / 1_000_000} MB or smaller` } };
  return null;
}

function userId(request) { return request.bodyCompassAuth?.userId ?? "local-owner"; }
function badRequest(message) { return { status: 400, body: { error: message } }; }
