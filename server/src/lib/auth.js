import { createHash } from "node:crypto";
import { persistenceStore } from "../persistence/database.js";

export function authenticate(request, store = persistenceStore()) {
  const token = bearerToken(request);
  if (!token) {
    return { ok: false, status: 401, body: { error: "Sign in is required" } };
  }

  const session = store.sessionByTokenHash(hashSessionToken(token));
  return session
    ? { ok: true, userId: session.userId, email: session.email, displayName: session.displayName, emailVerified: session.emailVerified, mode: "session" }
    : { ok: false, status: 401, body: { error: "Your session has expired. Please sign in again." } };
}

export function bearerToken(request) {
  const value = request.headers?.authorization ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(value);
  return match?.[1]?.trim() ?? "";
}

export function hashSessionToken(token) {
  return createHash("sha256").update(token).digest("hex");
}
