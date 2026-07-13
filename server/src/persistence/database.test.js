import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { BodyCompassStore } from "./database.js";

test("SQLite data and encrypted images survive reopening, export, and deletion", async () => {
  const root = await mkdtemp(join(tmpdir(), "bodycompass-store-"));
  const options = {
    databasePath: join(root, "bodycompass.sqlite"),
    imageDirectory: join(root, "images"),
    storageSecret: "test-storage-secret"
  };
  const photo = Buffer.from("private image bytes").toString("base64");
  let store = new BodyCompassStore(options);
  store.saveProfile("rohan", { name: "Rohan", targetBodyFatPercentage: 12 });
  store.saveHealthSnapshot("rohan", { date: "2026-07-13", weightKg: 78.2 });
  await store.saveMeal("rohan", {
    id: "meal-1",
    accepted: { caloriesRange: [600, 700], proteinGrams: 40 },
    imageBase64: photo,
    imageMimeType: "image/jpeg"
  });
  await store.saveProgressCheckIn("rohan", {
    id: "check-1",
    analysis: { bodyFatRange: [16, 20] },
    photos: ["front", "side", "back"].map((pose) => ({ pose, imageBase64: photo, imageMimeType: "image/jpeg" }))
  });
  store.close();

  store = new BodyCompassStore(options);
  const exported = await store.exportUser("rohan", true);
  assert.equal(exported.profile.name, "Rohan");
  assert.equal(exported.healthSnapshots[0].weightKg, 78.2);
  assert.equal(exported.meals[0].imageBase64, photo);
  assert.equal(exported.progressCheckIns[0].photos.length, 3);

  await store.deleteUserData("rohan");
  const empty = await store.exportUser("rohan", false);
  assert.equal(empty.profile, null);
  assert.deepEqual(empty.meals, []);
  assert.deepEqual(empty.progressCheckIns, []);
  store.close();
  await rm(root, { recursive: true, force: true });
});

test("repeated sync replaces encrypted records idempotently", async () => {
  const root = await mkdtemp(join(tmpdir(), "bodycompass-replace-"));
  const store = new BodyCompassStore({ databasePath: join(root, "db.sqlite"), imageDirectory: join(root, "images"), storageSecret: "secret" });
  const first = Buffer.from("first").toString("base64");
  const second = Buffer.from("second").toString("base64");
  await store.saveMeal("owner", { id: "same", accepted: { proteinGrams: 10 }, imageBase64: first, imageMimeType: "image/jpeg" });
  await store.saveMeal("owner", { id: "same", accepted: { proteinGrams: 20 }, imageBase64: second, imageMimeType: "image/jpeg" });
  const exported = await store.exportUser("owner", true);
  assert.equal(exported.meals.length, 1);
  assert.equal(exported.meals[0].accepted.proteinGrams, 20);
  assert.equal(exported.meals[0].imageBase64, second);
  store.close();
  await rm(root, { recursive: true, force: true });
});
