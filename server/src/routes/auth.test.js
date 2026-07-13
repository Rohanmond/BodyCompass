import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Readable } from "node:stream";
import test from "node:test";

test("account registration, login, session validation, and logout work together", async () => {
  const root = await mkdtemp(join(tmpdir(), "bodycompass-auth-flow-"));
  process.env.BODYCOMPASS_DATA_DIR = root;
  delete process.env.RESEND_API_KEY;
  delete process.env.NODE_ENV;
  const [{ register, login, logout, requestEmailCode, verifyEmailCode }, { authenticate }, { closePersistenceStore }] = await Promise.all([
    import("./auth.js"),
    import("../lib/auth.js"),
    import("../persistence/database.js")
  ]);

  const created = await register(request({
    displayName: "Rohan Mondal",
    email: "Rohan@Example.com",
    password: "BodyCompass123"
  }));
  assert.equal(created.status, 201);
  assert.equal(created.body.user.email, "rohan@example.com");
  assert.equal(typeof created.body.token, "string");

  const signedIn = await login(request({ email: "rohan@example.com", password: "BodyCompass123" }));
  assert.equal(signedIn.status, 200);
  const authorizedRequest = request({}, signedIn.body.token);
  const authenticated = authenticate(authorizedRequest);
  assert.equal(authenticated.ok, true);
  assert.equal(authenticated.userId, created.body.user.id);

  assert.equal(logout(authorizedRequest).status, 204);
  assert.equal(authenticate(authorizedRequest).status, 401);

  const requested = await requestEmailCode(request({ email: "otp@example.com" }));
  assert.equal(requested.status, 202);
  assert.match(requested.body.developmentCode, /^\d{6}$/);
  const verified = await verifyEmailCode(request({
    challengeId: requested.body.challengeId,
    code: requested.body.developmentCode
  }));
  assert.equal(verified.status, 201);
  assert.equal(verified.body.user.email, "otp@example.com");
  assert.equal(verified.body.user.emailVerified, true);
  assert.equal(authenticate(request({}, verified.body.token)).ok, true);
  const replayed = await verifyEmailCode(request({
    challengeId: requested.body.challengeId,
    code: requested.body.developmentCode
  }));
  assert.equal(replayed.status, 401);

  closePersistenceStore();
  delete process.env.BODYCOMPASS_DATA_DIR;
  await rm(root, { recursive: true, force: true });
});

function request(body, token) {
  const stream = Readable.from([JSON.stringify(body)]);
  stream.headers = token ? { authorization: `Bearer ${token}` } : {};
  stream.socket = { remoteAddress: "127.0.0.1" };
  return stream;
}
