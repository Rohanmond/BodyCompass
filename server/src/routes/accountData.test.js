import assert from "node:assert/strict";
import test from "node:test";
import { saveMealRecord, saveProgressRecord } from "./accountData.js";

test("meal history rejects photo fields", async () => {
  const result = await saveMealRecord(requestWith({
    id: "meal-1",
    accepted: { proteinGrams: 30 },
    imageBase64: "aGVsbG8=",
    imageMimeType: "image/jpeg"
  }));

  assert.equal(result.status, 400);
  assert.equal(result.body.error, "Meal history does not accept photos");
});

test("progress history rejects photo fields", async () => {
  const result = await saveProgressRecord(requestWith({
    id: "check-in-1",
    analysis: { bodyFatRange: [16, 19] },
    photos: []
  }));

  assert.equal(result.status, 400);
  assert.equal(result.body.error, "Progress history does not accept photos");
});

function requestWith(body) {
  const data = Buffer.from(JSON.stringify(body));
  return {
    async *[Symbol.asyncIterator]() {
      yield data;
    }
  };
}
