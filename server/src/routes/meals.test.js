import assert from "node:assert/strict";
import test from "node:test";
import { analyzeMeal } from "./meals.js";

test("meal endpoint rejects unsupported image types", async () => {
  const result = await analyzeMeal(requestWith({
    imageBase64: "aGVsbG8=",
    imageMimeType: "image/heic"
  }));

  assert.equal(result.status, 415);
  assert.match(result.body.error, /image\/jpeg/);
});

test("meal endpoint rejects malformed base64", async () => {
  const result = await analyzeMeal(requestWith({
    imageBase64: "not base64!",
    imageMimeType: "image/jpeg"
  }));

  assert.equal(result.status, 400);
  assert.match(result.body.error, /valid base64/);
});

function requestWith(body) {
  const data = Buffer.from(JSON.stringify(body));
  return {
    async *[Symbol.asyncIterator]() {
      yield data;
    }
  };
}
