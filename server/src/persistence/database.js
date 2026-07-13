import { randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
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
    `);
  }

  ensureUser(userId) {
    const now = new Date().toISOString();
    this.db.prepare(`INSERT INTO users (id, created_at, updated_at) VALUES (?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at`).run(userId, now, now);
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
    let imageRef = null;
    if (imageBase64) imageRef = await this.files.save(Buffer.from(imageBase64, "base64"));
    const now = payload.createdAt || new Date().toISOString();
    try {
      this.db.prepare("INSERT OR REPLACE INTO meals (id, user_id, payload, image_ref, created_at) VALUES (?, ?, ?, ?, ?)")
        .run(id, userId, JSON.stringify(payload), imageRef, now);
    } catch (error) {
      await this.files.delete(imageRef);
      throw error;
    }
    if (previous?.image_ref && previous.image_ref !== imageRef) await this.files.delete(previous.image_ref);
    return { id, ...payload, hasImage: Boolean(imageRef), createdAt: now };
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
    const refs = [];
    const oldRefs = this.db.prepare(`SELECT pp.image_ref FROM progress_photos pp
      JOIN progress_check_ins pc ON pc.id = pp.check_in_id WHERE pc.id = ? AND pc.user_id = ?`).all(id, userId);
    try {
      for (const photo of photos) {
        refs.push({
          pose: photo.pose,
          mimeType: photo.imageMimeType,
          imageRef: await this.files.save(Buffer.from(photo.imageBase64, "base64"))
        });
      }
      const now = payload.capturedAt || new Date().toISOString();
      this.db.exec("BEGIN IMMEDIATE");
      this.db.prepare("DELETE FROM progress_check_ins WHERE id = ? AND user_id = ?").run(id, userId);
      this.db.prepare("INSERT INTO progress_check_ins (id, user_id, payload, created_at) VALUES (?, ?, ?, ?)")
        .run(id, userId, JSON.stringify(payload), now);
      const statement = this.db.prepare("INSERT INTO progress_photos (check_in_id, pose, image_ref, mime_type) VALUES (?, ?, ?, ?)");
      refs.forEach((photo) => statement.run(id, photo.pose, photo.imageRef, photo.mimeType));
      this.db.exec("COMMIT");
      await Promise.all(oldRefs.map((photo) => this.files.delete(photo.image_ref)));
      return { id, ...payload, poses: refs.map((photo) => photo.pose), capturedAt: now };
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch {}
      await Promise.all(refs.map((photo) => this.files.delete(photo.imageRef)));
      throw error;
    }
  }

  async deleteProgressCheckIn(userId, id) {
    const refs = this.db.prepare(`SELECT pp.image_ref FROM progress_photos pp
      JOIN progress_check_ins pc ON pc.id = pp.check_in_id WHERE pc.id = ? AND pc.user_id = ?`).all(id, userId);
    if (!refs.length && !this.db.prepare("SELECT id FROM progress_check_ins WHERE id = ? AND user_id = ?").get(id, userId)) return false;
    this.db.prepare("DELETE FROM progress_check_ins WHERE id = ? AND user_id = ?").run(id, userId);
    await Promise.all(refs.map((row) => this.files.delete(row.image_ref)));
    return true;
  }

  async exportUser(userId, includeImages = false) {
    const profile = this.db.prepare("SELECT payload, updated_at FROM profiles WHERE user_id = ?").get(userId);
    const schedule = this.db.prepare("SELECT payload, updated_at FROM schedules WHERE user_id = ?").get(userId);
    const meals = this.db.prepare("SELECT id, payload, image_ref, created_at FROM meals WHERE user_id = ? ORDER BY created_at").all(userId);
    const chats = this.db.prepare("SELECT id, request_payload, response_payload, created_at FROM chats WHERE user_id = ? ORDER BY created_at").all(userId);
    const progress = this.db.prepare("SELECT id, payload, created_at FROM progress_check_ins WHERE user_id = ? ORDER BY created_at").all(userId);
    for (const checkIn of progress) {
      const photos = this.db.prepare("SELECT pose, image_ref, mime_type FROM progress_photos WHERE check_in_id = ? ORDER BY pose").all(checkIn.id);
      checkIn.photos = await Promise.all(photos.map(async (photo) => ({
        pose: photo.pose,
        imageMimeType: photo.mime_type,
        ...(includeImages ? { imageBase64: (await this.files.read(photo.image_ref)).toString("base64") } : { hasImage: true })
      })));
    }
    return {
      exportedAt: new Date().toISOString(),
      userId,
      profile: profile ? { ...JSON.parse(profile.payload), updatedAt: profile.updated_at } : null,
      healthSnapshots: this.listHealthSnapshots(userId),
      schedule: schedule ? { items: JSON.parse(schedule.payload), updatedAt: schedule.updated_at } : null,
      meals: await Promise.all(meals.map(async (meal) => ({
        id: meal.id,
        ...JSON.parse(meal.payload),
        createdAt: meal.created_at,
        ...(includeImages && meal.image_ref ? { imageBase64: (await this.files.read(meal.image_ref)).toString("base64") } : { hasImage: Boolean(meal.image_ref) })
      }))),
      chats: chats.map((chat) => ({ id: chat.id, request: JSON.parse(chat.request_payload), response: JSON.parse(chat.response_payload), createdAt: chat.created_at })),
      progressCheckIns: progress.map((checkIn) => ({ id: checkIn.id, ...JSON.parse(checkIn.payload), capturedAt: checkIn.created_at, photos: checkIn.photos }))
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
