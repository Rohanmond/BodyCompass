import assert from "node:assert/strict";
import test from "node:test";
import { __progressTesting } from "./aiProviders.js";

function estimate(provider, range) {
  return {
    provider,
    mode: "live",
    bodyFatRange: range,
    confidence: 0.7,
    imageQuality: "good",
    visibleChanges: ["Waist appears slightly leaner"],
    limitations: ["Lighting differs"],
    suggestions: ["Repeat the same setup"],
    nextWeekAction: "Keep the plan stable."
  };
}

test("progress reconciliation widens two visual estimates", () => {
  const result = __progressTesting.reconcileProgress(
    estimate("openai", [16, 20]),
    estimate("gemini", [18, 22])
  );
  assert.deepEqual(result.bodyFatRange, [16, 22]);
  assert.equal(result.imageQuality, "good");
});

test("single-provider progress results expose lower confidence", () => {
  const result = __progressTesting.reconcileProgress(
    estimate("openai", [16, 20]),
    { provider: "gemini", mode: "error", error: "timeout" }
  );
  assert.equal(result.confidence, 0.5);
  assert.match(result.limitations.at(-1), /one provider/);
  assert.equal("provider" in result, false);
});

test("progress result normalization sorts and clamps range", () => {
  const result = __progressTesting.normalizeProgressResult("openai", {
    bodyFatRange: [64, 2],
    confidence: 4,
    imageQuality: "unknown",
    visibleChanges: [],
    limitations: [],
    suggestions: [],
    nextWeekAction: "Repeat photos."
  });
  assert.deepEqual(result.bodyFatRange, [3, 60]);
  assert.equal(result.confidence, 1);
  assert.equal(result.imageQuality, "limited");
});
