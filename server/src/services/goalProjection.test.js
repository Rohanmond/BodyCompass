import test from "node:test";
import assert from "node:assert/strict";
import { createProjection } from "./goalProjection.js";

test("creates projection for 12 percent body-fat goal", () => {
  const projection = createProjection({
    weightKg: 80,
    bodyFatPercentage: 22,
    targetBodyFatPercentage: 12,
    adherenceScore: 0.8
  });

  assert.equal(projection.currentFatMassKg, 17.6);
  assert.equal(projection.currentLeanMassKg, 62.4);
  assert.equal(projection.targetWeightKg, 70.9);
  assert.equal(projection.status, "onTrack");
  assert.ok(projection.optimumWeeks > 0);
});

test("returns maintenance projection when already at goal", () => {
  const projection = createProjection({
    weightKg: 72,
    bodyFatPercentage: 12,
    targetBodyFatPercentage: 12
  });

  assert.equal(projection.status, "alreadyAtGoal");
  assert.equal(projection.optimumWeeks, 0);
});

test("rejects invalid profile", () => {
  assert.throws(() => createProjection({ weightKg: 0, bodyFatPercentage: 20 }));
});
