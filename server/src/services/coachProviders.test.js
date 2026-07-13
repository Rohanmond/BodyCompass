import assert from "node:assert/strict";
import test from "node:test";
import {
  __chatTesting,
  chatWithProviders,
  classifyCoachSafety
} from "./aiProviders.js";

test("coach uses both mock providers and returns one next action", async () => {
  const result = await chatWithProviders({
    message: "What should I focus on today?",
    safetyCategory: "normal",
    context: { today: { steps: 4_000 } }
  });

  assert.equal(result.openai.mode, "mock");
  assert.equal(result.gemini.mode, "mock");
  assert.equal(result.combined.confidence, "dual_provider");
  assert.ok(result.combined.nextAction.length > 0);
});

test("explicit routine review creates a pending change instruction", async () => {
  const result = await chatWithProviders({
    message: "Please review and change my training routine",
    safetyCategory: "normal",
    context: { training: { setupComplete: true } }
  });

  assert.equal(result.combined.routineProposal.changes[0].action, "update_swim");
});

test("safety classifier catches high-risk coaching requests", () => {
  assert.equal(classifyCoachSafety("I have chest pain and can't breathe"), "urgent_medical");
  assert.equal(classifyCoachSafety("Can I eat 500 calories every day?"), "extreme_deficit");
  assert.equal(classifyCoachSafety("My shoulder has sharp pain"), "injury");
  assert.equal(classifyCoachSafety("How are my steps today?"), "normal");
});

test("unsafe answers cannot carry routine proposals", () => {
  const provider = {
    provider: "openai",
    mode: "live",
    answer: "Stop training.",
    nextAction: "Seek help.",
    safetyNotice: "",
    routineProposal: { changes: [{ action: "make_rest_day" }] }
  };
  const result = __chatTesting.reconcileCoachAnswers(provider, provider, "urgent_medical");

  assert.equal(result.routineProposal, null);
  assert.match(result.safetyNotice, /urgent medical help/);
});

test("coach falls back when one provider fails", () => {
  const answer = {
    provider: "openai",
    mode: "live",
    answer: "Keep the current moderate plan.",
    nextAction: "Finish today's walk.",
    safetyNotice: "",
    routineProposal: null
  };
  const error = { provider: "gemini", mode: "error", error: "Timed out" };

  const result = __chatTesting.reconcileCoachAnswers(answer, error, "normal");
  assert.equal(result.confidence, "single_provider");
  assert.equal(result.answer, answer.answer);
});
