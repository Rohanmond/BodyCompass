import assert from "node:assert/strict";
import test from "node:test";
import { createChatAnswer } from "./chat.js";

test("chat endpoint requires a message", async () => {
  const result = await createChatAnswer(requestWith({ context: {} }));
  assert.equal(result.status, 400);
});

test("chat endpoint bounds message length", async () => {
  const result = await createChatAnswer(requestWith({ message: "a".repeat(2_001) }));
  assert.equal(result.status, 413);
});

function requestWith(body) {
  const data = Buffer.from(JSON.stringify(body));
  return {
    async *[Symbol.asyncIterator]() {
      yield data;
    }
  };
}
