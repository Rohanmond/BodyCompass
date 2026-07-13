import assert from "node:assert/strict";
import test from "node:test";
import { authenticate } from "./auth.js";

test("authentication defaults to local private mode without a configured token", () => {
  const previous = process.env.BODYCOMPASS_API_TOKEN;
  delete process.env.BODYCOMPASS_API_TOKEN;
  const result = authenticate({ headers: {} });
  restore("BODYCOMPASS_API_TOKEN", previous);
  assert.equal(result.ok, true);
  assert.equal(result.mode, "local_private");
});

test("configured bearer authentication rejects an invalid token", () => {
  const previous = process.env.BODYCOMPASS_API_TOKEN;
  process.env.BODYCOMPASS_API_TOKEN = "correct-token";
  const rejected = authenticate({ headers: { authorization: "Bearer wrong-token" } });
  const accepted = authenticate({ headers: { authorization: "Bearer correct-token" } });
  restore("BODYCOMPASS_API_TOKEN", previous);
  assert.equal(rejected.status, 401);
  assert.equal(accepted.ok, true);
});

function restore(key, value) {
  if (value === undefined) delete process.env[key];
  else process.env[key] = value;
}
