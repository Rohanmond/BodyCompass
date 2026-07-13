import assert from "node:assert/strict";
import test from "node:test";
import { analyzeProgressCheckIn } from "./progressCheckIns.js";

const imageBase64 = Buffer.from("small image").toString("base64");

test("progress endpoint requires standardized capture confirmations", async () => {
  const result = await analyzeProgressCheckIn(requestWith({ currentPhotos: photos() }));
  assert.equal(result.status, 400);
  assert.match(result.body.error, /Confirm morning/);
});

test("progress endpoint requires one photo for every pose", async () => {
  const result = await analyzeProgressCheckIn(requestWith({
    confirmations: confirmations(),
    currentPhotos: photos().slice(0, 2)
  }));
  assert.equal(result.status, 400);
  assert.match(result.body.error, /front, side, and back/);
});

test("progress endpoint returns dual mock estimates", async () => {
  const result = await analyzeProgressCheckIn(requestWith({
    confirmations: confirmations(),
    currentPhotos: photos(),
    context: { currentBodyFatPercentage: 18 }
  }));
  assert.equal(result.status, 200);
  assert.equal(result.body.openai.mode, "mock");
  assert.deepEqual(result.body.reconciled.bodyFatRange, [15, 21]);
});

function confirmations() {
  return { morning: true, consistentLighting: true, fullBody: true };
}

function photos() {
  return ["front", "side", "back"].map((pose) => ({
    pose,
    imageBase64,
    imageMimeType: "image/jpeg"
  }));
}

function requestWith(body) {
  const data = Buffer.from(JSON.stringify(body));
  return { async *[Symbol.asyncIterator]() { yield data; } };
}
