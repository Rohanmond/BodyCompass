import { randomUUID } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { PrivateFileStore } from "./privateFiles.js";

export class BodyCompassStore {
  constructor({ databasePath, imageDirectory, storageSecret }) {
    const path = resolve(databasePath);
    mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
    this.db = new DatabaseSync(path);
    this.files = new PrivateFileStore({ directory: imageDirectory, secret: storageSecret });
    this.db.exec("PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;");
    this.migrate();
  }

  migrate() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS auth_accounts (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        display_name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS auth_sessions (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS profiles (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS health_snapshots (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        day TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_id, day)
      );
      CREATE TABLE IF NOT EXISTS schedules (
        user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS meals (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        payload TEXT NOT NULL,
        image_ref TEXT,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS chats (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        request_payload TEXT NOT NULL,
        response_payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS progress_check_ins (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS progress_photos (
        check_in_id TEXT NOT NULL REFERENCES progress_check_ins(id) ON DELETE CASCADE,
        pose TEXT NOT NULL,
        image_ref TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        PRIMARY KEY(check_in_id, pose)
      );
      CREATE INDEX IF NOT EXISTS health_user_day ON health_snapshots(user_id, day DESC);
      CREATE INDEX IF NOT EXISTS meals_user_created ON meals(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS chats_user_created ON chats(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS progress_user_created ON progress_check_ins(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS auth_sessions_user ON auth_sessions(user_id);
      CREATE INDEX IF NOT EXISTS auth_sessions_expiry ON auth_sessions(expires_at);
    `);
    // Photos are analysis-only. Purge files and legacy references on every startup.
    rmSync(this.files.directory, { recursive: true, force: true });
    this.db.prepare("UPDATE meals SET image_ref = NULL WHERE image_ref IS NOT NULL").run();
    this.db.prepare("DELETE FROM progress_photos").run();
  }

  ensureUser(userId) {
    const now = new Date().toISOString();
    this.db.prepare(`INSERT INTO users (id, created_at, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at`).run(userId, now, now);
  }

  createAccount({ userId = randomUUID(), email, displayName, passwordHash, passwordSalt }) {
    const now = new Date().toISOString();
    this.db.exec("BEGIN IMMEDIATE");
    try {
      this.db.prepare("INSERT INTO users (id, created_at, updated_at) VALUES (?, ?, ?)")
        .run(userId, now, now);
      this.db.prepare(`INSERT INTO auth_accounts
        (user_id, email, display_name, password_hash, password_salt, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)`)
        .run(userId, email, displayName, passwordHash, passwordSalt, now, now);
      this.db.exec("COMMIT");
    } catch (error) {
      this.db.exec("ROLLBACK");
      throw error;
    }
    return { id: userId, email, displayName, createdAt: now };
  }

  accountByEmail(email) {
    const row = this.db.prepare(`SELECT user_id, email, display_name, password_hash, password_salt, created_at
      FROM auth_accounts WHERE email = ? COLLATE NOCASE`).get(email);
    return row ? accountFromRow(row) : null;
  }

  accountByUserId(userId) {
    const row = this.db.prepare(`SELECT user_id, email, display_name, password_hash, password_salt, created_at
      FROM auth_accounts WHERE user_id = ?`).get(userId);
    return row ? accountFromRow(row) : null;
  }

  createSession(userId, tokenHash, expiresAt) {
    const now = new Date().toISOString();
    this.db.prepare("DELETE FROM auth_sessions WHERE expires_at <= ?").run(now);
    this.db.prepare("INSERT INTO auth_sessions (token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)")
      .run(tokenHash, userId, expiresAt, now);
  }

  sessionByTokenHash(tokenHash) {
    const now = new Date().toISOString();
    const row = this.db.prepare(`SELECT s.user_id, s.expires_at, a.email, a.display_name
      FROM auth_sessions s JOIN auth_accounts a ON a.user_id = s.user_id
      WHERE s.token_hash = ? AND s.expires_at > ?`).get(tokenHash, now);
    return row ? {
      userId: row.user_id,
      email: row.email,
      displayName: row.display_name,
      expiresAt: row.expires_at
    } : null;
  }

  deleteSession(tokenHash) {
    return this.db.prepare("DELETE FROM auth_sessions WHERE token_hash = ?").run(tokenHash).changes > 0;
  }

  saveProfile(userId, payload) {
    this.ensureUser(userId);
    const now = new Date().toISOString();
    this.db.prepare(`INSERT INTO profiles (user_id, payload, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`)
      .run(userId, JSON.stringify(payload), now);
    return { ...payload, updatedAt: now };
  }

  saveSchedule(userId, payload) {
    this.ensureUser(userId);
    const now = new Date().toISOString();
    this.db.prepare(`INSERT INTO schedules (user_id, payload, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(user_id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at`)
      .run(userId, JSON.stringify(payload), now);
    return { items: payload, updatedAt: now };
  }

  saveHealthSnapshot(userId, payload) {
    this.ensureUser(userId);
    const id = randomUUID();
    const now = new Date().toISOString();
    this.db.prepare(`INSERT INTO health_snapshots (id, user_id, day, payload, created_at) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id, day) DO UPDATE SET payload = excluded.payload, created_at = excluded.created_at`)
      .run(id, userId, payload.date, JSON.stringify(payload), now);
    const row = this.db.prepare("SELECT id, payload, created_at FROM health_snapshots WHERE user_id = ? AND day = ?").get(userId, payload.date);
    return { id: row.id, ...JSON.parse(row.payload), createdAt: row.created_at };
  }

  listHealthSnapshots(userId) {
    return this.db.prepare("SELECT id, payload, created_at FROM health_snapshots WHERE user_id = ? ORDER BY day DESC LIMIT 365")
      .all(userId).map((row) => ({ id: row.id, ...JSON.parse(row.payload), createdAt: row.created_at }));
  }

  async saveMeal(userId, { id = randomUUID(), imageBase64, imageMimeType, ...payload }) {
    this.ensureUser(userId);
    const previous = this.db.prepare("SELECT image_ref FROM meals WHERE id = ? AND user_id = ?").get(id, userId);
    const now = payload.createdAt || new Date().toISOString();
    this.db.prepare("INSERT OR REPLACE INTO meals (id, user_id, payload, image_ref, created_at) VALUES (?, ?, ?, NULL, ?)")
      .run(id, userId, JSON.stringify(payload), now);
    await this.files.delete(previous?.image_ref);
    return { id, ...payload, createdAt: now };
  }

  async deleteMeal(userId, id) {
    const row = this.db.prepare("SELECT image_ref FROM meals WHERE id = ? AND user_id = ?").get(id, userId);
    if (!row) return false;
    this.db.prepare("DELETE FROM meals WHERE id = ? AND user_id = ?").run(id, userId);
    await this.files.delete(row.image_ref);
    return true;
  }

  saveChat(userId, request, response) {
    this.ensureUser(userId);
    const id = randomUUID();
    const now = new Date().toISOString();
    this.db.prepare("INSERT INTO chats (id, user_id, request_payload, response_payload, created_at) VALUES (?, ?, ?, ?, ?)")
      .run(id, userId, JSON.stringify(request), JSON.stringify(response), now);
    return id;
  }

  async saveProgressCheckIn(userId, { id = randomUUID(), photos = [], ...payload }) {
    this.ensureUser(userId);
    const oldRefs = this.db.prepare(`SELECT pp.image_ref FROM progress_photos pp
      JOIN progress_check_ins pc ON pc.id = pp.check_in_id WHERE pc.id = ? AND pc.user_id = ?`).all(id, userId);
    const now = payload.capturedAt || new Date().toISOString();
    this.db.prepare("INSERT OR REPLACE INTO progress_check_ins (id, user_id, payload, created_at) VALUES (?, ?, ?, ?)")
      .run(id, userId, JSON.stringify(payload), now);
    await Promise.all(oldRefs.map((photo) => this.files.delete(photo.image_ref)));
    return { id, ...payload, capturedAt: now };
  }

  async deleteProgressCheckIn(userId, id) {
    const refs = this.db.prepare(`SELECT pp.image_ref FROM progress_photos pp
      JOIN progress_check_ins pc ON pc.id = pp.check_in_id WHERE pc.id = ? AND pc.user_id = ?`).all(id, userId);
    if (!refs.length && !this.db.prepare("SELECT id FROM progress_check_ins WHERE id = ? AND user_id = ?").get(id, userId)) return false;
    this.db.prepare("DELETE FROM progress_check_ins WHERE id = ? AND user_id = ?").run(id, userId);
    await Promise.all(refs.map((row) => this.files.delete(row.image_ref)));
    return true;
  }

  async exportUser(userId) {
    const profile = this.db.prepare("SELECT payload, updated_at FROM profiles WHERE user_id = ?").get(userId);
    const schedule = this.db.prepare("SELECT payload, updated_at FROM schedules WHERE user_id = ?").get(userId);
    const meals = this.db.prepare("SELECT id, payload, created_at FROM meals WHERE user_id = ? ORDER BY created_at").all(userId);
    const chats = this.db.prepare("SELECT id, request_payload, response_payload, created_at FROM chats WHERE user_id = ? ORDER BY created_at").all(userId);
    const progress = this.db.prepare("SELECT id, payload, created_at FROM progress_check_ins WHERE user_id = ? ORDER BY created_at").all(userId);
    return {
      exportedAt: new Date().toISOString(),
      userId,
      profile: profile ? { ...JSON.parse(profile.payload), updatedAt: profile.updated_at } : null,
      healthSnapshots: this.listHealthSnapshots(userId),
      schedule: schedule ? { items: JSON.parse(schedule.payload), updatedAt: schedule.updated_at } : null,
      meals: meals.map((meal) => ({
        id: meal.id,
        ...JSON.parse(meal.payload),
        createdAt: meal.created_at
      })),
      chats: chats.map((chat) => ({ id: chat.id, request: JSON.parse(chat.request_payload), response: JSON.parse(chat.response_payload), createdAt: chat.created_at })),
      progressCheckIns: progress.map((checkIn) => ({ id: checkIn.id, ...JSON.parse(checkIn.payload), capturedAt: checkIn.created_at }))
    };
  }

  async deleteUserData(userId) {
    const mealRefs = this.db.prepare("SELECT image_ref FROM meals WHERE user_id = ? AND image_ref IS NOT NULL").all(userId);
    const progressRefs = this.db.prepare(`SELECT pp.image_ref FROM progress_photos pp
      JOIN progress_check_ins pc ON pc.id = pp.check_in_id WHERE pc.user_id = ?`).all(userId);
    this.db.prepare("DELETE FROM users WHERE id = ?").run(userId);
    await Promise.all([...mealRefs, ...progressRefs].map((row) => this.files.delete(row.image_ref)));
    return { deleted: true };
  }

  healthCheck() {
    const result = this.db.prepare("PRAGMA quick_check").get();
    return Object.values(result)[0] === "ok";
  }

  close() { this.db.close(); }
}

let sharedStore;
export function persistenceStore() {
  if (!sharedStore) {
    const root = resolve(process.env.BODYCOMPASS_DATA_DIR ?? "server-data");
    sharedStore = new BodyCompassStore({
      databasePath: process.env.BODYCOMPASS_DATABASE_PATH ?? `${root}/bodycompass.sqlite`,
      imageDirectory: process.env.BODYCOMPASS_IMAGE_DIR ?? `${root}/private-images`,
      storageSecret: process.env.BODYCOMPASS_STORAGE_SECRET ?? process.env.BODYCOMPASS_API_TOKEN ?? "bodycompass-local-development-only"
    });
  }
  return sharedStore;
}

export function closePersistenceStore() {
  if (!sharedStore) return;
  sharedStore.close();
  sharedStore = undefined;
}

function accountFromRow(row) {
  return {
    id: row.user_id,
    email: row.email,
    displayName: row.display_name,
    passwordHash: row.password_hash,
    passwordSalt: row.password_salt,
    createdAt: row.created_at
  };
}
