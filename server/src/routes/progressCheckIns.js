import { readJson } from "../lib/readJson.js";
import { analyzeProgressWithProviders } from "../services/aiProviders.js";
import { consumeAIQuota } from "../lib/aiQuota.js";

const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const requiredPoses = new Set(["front", "side", "back"]);

export async function analyzeProgressCheckIn(request) {
  const body = await readJson(request, 35_000_000);
  const confirmation = body.confirmations ?? {};
  if (!confirmation.morning || !confirmation.consistentLighting || !confirmation.fullBody) {
    return { status: 400, body: { error: "Confirm morning, consistent lighting, and full-body framing" } };
  }

  const currentError = validatePhotos(body.currentPhotos, true);
  if (currentError) return currentError;

  const quotaResponse = consumeAIQuota(request, "progress");
  if (quotaResponse) return quotaResponse;

  try {
    return { status: 200, body: await analyzeProgressWithProviders(body) };
  } catch (error) {
    return {
      status: 502,
      body: {
        error: "Progress analysis providers are unavailable",
        detail: error instanceof Error ? error.message : "Unknown provider error"
      }
    };
  }
}

function validatePhotos(photos, requireAllPoses) {
  if (!Array.isArray(photos) || photos.length > 3 || (requireAllPoses && photos.length !== 3)) {
    return { status: 400, body: { error: requireAllPoses ? "Provide front, side, and back photos" : "Previous photos may contain at most three images" } };
  }
  const poses = new Set();
  let totalBytes = 0;
  for (const photo of photos) {
    if (!requiredPoses.has(photo?.pose) || poses.has(photo.pose)) {
      return { status: 400, body: { error: "Photos must use unique front, side, and back poses" } };
    }
    poses.add(photo.pose);
    if (!allowedTypes.has(photo.imageMimeType)) {
      return { status: 415, body: { error: "Photos must be JPEG, PNG, or WebP" } };
    }
    if (typeof photo.imageBase64 !== "string" || !/^[A-Za-z0-9+/]+={0,2}$/.test(photo.imageBase64)) {
      return { status: 400, body: { error: "A progress photo contains invalid base64" } };
    }
    const bytes = Buffer.byteLength(photo.imageBase64, "base64");
    if (bytes > 6_000_000) return { status: 413, body: { error: "Each progress photo must be 6 MB or smaller" } };
    totalBytes += bytes;
  }
  if (totalBytes > 18_000_000) return { status: 413, body: { error: "Progress photos must total 18 MB or less" } };
  return null;
}
