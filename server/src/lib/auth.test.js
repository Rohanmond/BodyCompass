import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { authenticate, hashSessionToken } from "./auth.js";
import { BodyCompassStore } from "../persistence/database.js";

test("authentication requires a valid, unexpired account session", async () => {
  const root = await mkdtemp(join(tmpdir(), "bodycompass-auth-"));
  const store = new BodyCompassStore({ databasePath: join(root, "db.sqlite"), imageDirectory: join(root, "images"), storageSecret: "secret" });
  const user = store.createAccount({
    email: "rohan@example.com",
    displayName: "Rohan",
    passwordHash: "hash",
    passwordSalt: "salt"
  });
  store.createSession(user.id, hashSessionToken("valid-token"), new Date(Date.now() + 60_000).toISOString());
  store.createSession(user.id, hashSessionToken("expired-token"), new Date(Date.now() - 60_000).toISOString());

  assert.equal(authenticate({ headers: {} }, store).status, 401);
  assert.equal(authenticate({ headers: { authorization: "Bearer wrong-token" } }, store).status, 401);
  assert.equal(authenticate({ headers: { authorization: "Bearer expired-token" } }, store).status, 401);
  const accepted = authenticate({ headers: { authorization: "Bearer valid-token" } }, store);
  assert.equal(accepted.ok, true);
  assert.equal(accepted.userId, user.id);
  assert.equal(accepted.email, "rohan@example.com");

  store.close();
  await rm(root, { recursive: true, force: true });
});
