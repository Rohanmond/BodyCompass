import { createHash } from "node:crypto";
import { copyFile, mkdir, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";

export function configuredDatabasePath(environment = process.env) {
  const root = resolve(environment.BODYCOMPASS_DATA_DIR ?? "server-data");
  return resolve(environment.BODYCOMPASS_DATABASE_PATH ?? `${root}/bodycompass.sqlite`);
}

export async function backupDatabase(sourcePath, backupPath) {
  const source = resolve(sourcePath);
  const destination = resolve(backupPath);
  await requireFile(source, "Source database");
  await refuseExisting(destination);
  await refuseExisting(`${destination}.json`);
  await mkdir(dirname(destination), { recursive: true, mode: 0o700 });

  const database = new DatabaseSync(source);
  try {
    database.prepare("VACUUM INTO ?").run(destination);
  } finally {
    database.close();
  }

  const integrity = inspectDatabase(destination);
  if (!integrity.ok) {
    await rm(destination, { force: true });
    throw new Error(`Backup integrity check failed: ${integrity.message}`);
  }

  const bytes = await readFile(destination);
  const manifest = {
    format: "bodycompass-sqlite-backup-v1",
    createdAt: new Date().toISOString(),
    containsPhotos: false,
    bytes: bytes.length,
    sha256: sha256(bytes)
  };
  await writeFile(`${destination}.json`, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600, flag: "wx" });
  return manifest;
}

export async function restoreDatabase(backupPath, destinationPath) {
  const source = resolve(backupPath);
  const destination = resolve(destinationPath);
  await requireFile(source, "Backup database");
  const manifest = JSON.parse(await readFile(`${source}.json`, "utf8"));
  if (manifest.format !== "bodycompass-sqlite-backup-v1" || manifest.containsPhotos !== false) {
    throw new Error("Backup manifest is not a supported photo-free BodyCompass backup");
  }

  const sourceBytes = await readFile(source);
  if (sha256(sourceBytes) !== manifest.sha256 || sourceBytes.length !== manifest.bytes) {
    throw new Error("Backup checksum or size does not match its manifest");
  }
  const integrity = inspectDatabase(source);
  if (!integrity.ok) throw new Error(`Backup integrity check failed: ${integrity.message}`);

  await mkdir(dirname(destination), { recursive: true, mode: 0o700 });
  const temporary = `${destination}.restore-${process.pid}`;
  await copyFile(source, temporary);
  let previousPath = null;
  try {
    await stat(destination);
    previousPath = `${destination}.before-restore-${new Date().toISOString().replaceAll(":", "-")}`;
    await rename(destination, previousPath);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }

  try {
    await rename(temporary, destination);
    await rm(`${destination}-wal`, { force: true });
    await rm(`${destination}-shm`, { force: true });
  } catch (error) {
    if (previousPath) await rename(previousPath, destination);
    throw error;
  } finally {
    await rm(temporary, { force: true });
  }
  return { restored: true, previousPath, sha256: manifest.sha256 };
}

function inspectDatabase(path) {
  const database = new DatabaseSync(path, { readOnly: true });
  try {
    const result = database.prepare("PRAGMA integrity_check").get();
    const message = String(Object.values(result)[0]);
    return { ok: message === "ok", message };
  } finally {
    database.close();
  }
}

async function requireFile(path, label) {
  try {
    const details = await stat(path);
    if (!details.isFile()) throw new Error(`${label} is not a file: ${path}`);
  } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`${label} does not exist: ${path}`);
    throw error;
  }
}

async function refuseExisting(path) {
  try {
    await stat(path);
    throw new Error(`Refusing to overwrite existing backup: ${path}`);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
}

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}
