import assert from "node:assert/strict";
import test from "node:test";
import { analyzeMealWithProviders, __testing } from "./aiProviders.js";

test("mock meal analysis returns two estimates and a reconciliation", async () => {
  const result = await analyzeMealWithProviders({ notes: "Chicken, rice, and vegetables" });

  assert.equal(result.openai.mode, "mock");
  assert.equal(result.gemini.mode, "mock");
  assert.deepEqual(result.reconciled.caloriesRange, [620, 780]);
  assert.equal(result.reconciled.proteinGrams, 42);
});

test("reconciliation remains useful when one provider fails", () => {
  const estimate = {
    provider: "openai",
    mode: "live",
    title: "Rice bowl",
    caloriesRange: [500, 650],
    proteinGrams: 35,
    carbsGrams: 70,
    fatGrams: 15,
    confidence: 0.8,
    likelyMistakes: ["Oil may be hidden"],
    recommendation: "Confirm the rice portion."
  };
  const error = { provider: "gemini", mode: "error", error: "Timed out" };

  const result = __testing.reconcileMeal(estimate, error);

  assert.deepEqual(result.caloriesRange, [500, 650]);
  assert.equal(result.confidence, 0.55);
  assert.ok(result.likelyMistakes.includes("Gemini estimate unavailable"));
});

test("reconciliation fails only when both providers fail", () => {
  const openai = { provider: "openai", mode: "error", error: "No response" };
  const gemini = { provider: "gemini", mode: "error", error: "No response" };

  assert.throws(() => __testing.reconcileMeal(openai, gemini), /Both OpenAI and Gemini failed/);
});

test("provider results are normalized before reaching the app", () => {
  const result = __testing.normalizeMealResult("openai", {
    title: "Toast",
    caloriesRange: [410.8, 300.2],
    proteinGrams: -2,
    carbsGrams: 40.4,
    fatGrams: 9.7,
    confidence: 1.4,
    likelyMistakes: ["Spread", "Bread size"],
    recommendation: "Measure the spread."
  });

  assert.deepEqual(result.caloriesRange, [300, 411]);
  assert.equal(result.proteinGrams, 0);
  assert.equal(result.confidence, 1);
});
