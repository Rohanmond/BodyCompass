import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";
import { backupDatabase, restoreDatabase } from "./databaseBackup.js";

test("backup and restore preserve metadata with a verified photo-free manifest", async () => {
  const root = await mkdtemp(join(tmpdir(), "bodycompass-backup-"));
  const live = join(root, "live.sqlite");
  const backup = join(root, "backups", "snapshot.sqlite");
  const database = new DatabaseSync(live);
  database.exec("CREATE TABLE records (value TEXT); INSERT INTO records VALUES ('before');");
  database.close();

  const manifest = await backupDatabase(live, backup);
  assert.equal(manifest.containsPhotos, false);
  assert.equal(manifest.sha256.length, 64);

  const changed = new DatabaseSync(live);
  changed.exec("UPDATE records SET value = 'after'");
  changed.close();

  const restored = await restoreDatabase(backup, live);
  assert.ok(restored.previousPath);
  const result = new DatabaseSync(live, { readOnly: true });
  assert.equal(result.prepare("SELECT value FROM records").get().value, "before");
  result.close();

  const serializedManifest = JSON.parse(await readFile(`${backup}.json`, "utf8"));
  assert.equal(serializedManifest.containsPhotos, false);
  await rm(root, { recursive: true, force: true });
});

test("restore rejects a backup whose bytes no longer match the manifest", async () => {
  const root = await mkdtemp(join(tmpdir(), "bodycompass-tamper-"));
  const live = join(root, "live.sqlite");
  const backup = join(root, "snapshot.sqlite");
  const database = new DatabaseSync(live);
  database.exec("CREATE TABLE records (value TEXT)");
  database.close();
  await backupDatabase(live, backup);
  await writeFile(backup, "tampered");
  await assert.rejects(() => restoreDatabase(backup, live), /checksum or size/);
  await rm(root, { recursive: true, force: true });
});
