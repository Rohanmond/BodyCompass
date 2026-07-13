import { timingSafeEqual } from "node:crypto";

export function authenticate(request) {
  const configured = process.env.BODYCOMPASS_API_TOKEN;
  const userId = process.env.BODYCOMPASS_USER_ID ?? "local-owner";
  if (!configured) return { ok: true, userId, mode: "local_private" };

  const supplied = request.headers?.authorization?.replace(/^Bearer\s+/i, "") ?? "";
  const expectedBuffer = Buffer.from(configured);
  const suppliedBuffer = Buffer.from(supplied);
  const matches = expectedBuffer.length === suppliedBuffer.length
    && timingSafeEqual(expectedBuffer, suppliedBuffer);
  return matches
    ? { ok: true, userId, mode: "bearer" }
    : { ok: false, status: 401, body: { error: "Valid Bearer authentication is required" } };
}
