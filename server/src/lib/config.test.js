import assert from "node:assert/strict";
import test from "node:test";
import { loadConfig } from "./config.js";

test("local configuration works without credentials", () => {
  const config = loadConfig({ HOST: "127.0.0.1", PORT: "8080" });
  assert.equal(config.valid, true);
  assert.equal(config.production, false);
});

test("non-local binding requires a strong bearer token", () => {
  const config = loadConfig({ HOST: "0.0.0.0", BODYCOMPASS_API_TOKEN: "short" });
  assert.equal(config.valid, false);
  assert.match(config.errors.join(" "), /32 characters/);
});

test("production requires durable storage, identity, and both AI providers", () => {
  const config = loadConfig({
    NODE_ENV: "production",
    HOST: "0.0.0.0",
    BODYCOMPASS_API_TOKEN: "x".repeat(48),
    BODYCOMPASS_USER_ID: "rohan-production",
    BODYCOMPASS_DATA_DIR: "/data",
    OPENAI_API_KEY: "openai-secret",
    GEMINI_API_KEY: "gemini-secret"
  });
  assert.equal(config.valid, true);

  const invalid = loadConfig({ NODE_ENV: "production", HOST: "0.0.0.0" });
  assert.equal(invalid.valid, false);
  assert.match(invalid.errors.join(" "), /OPENAI_API_KEY/);
  assert.match(invalid.errors.join(" "), /GEMINI_API_KEY/);
  assert.match(invalid.errors.join(" "), /durable-volume/);

  const placeholders = loadConfig({
    NODE_ENV: "production",
    HOST: "0.0.0.0",
    BODYCOMPASS_API_TOKEN: "replace-with-at-least-32-random-characters",
    BODYCOMPASS_USER_ID: "replace-with-a-stable-private-owner-id",
    BODYCOMPASS_DATA_DIR: "/data",
    OPENAI_API_KEY: "openai-secret",
    GEMINI_API_KEY: "gemini-secret"
  });
  assert.equal(placeholders.valid, false);
  assert.match(placeholders.errors.join(" "), /non-placeholder/);
});
