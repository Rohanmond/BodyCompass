import { createCipheriv, createDecipheriv, createHash, randomBytes, randomUUID } from "node:crypto";
import { mkdir, readFile, rm, writeFile, chmod } from "node:fs/promises";
import { resolve } from "node:path";

export class PrivateFileStore {
  constructor({ directory, secret }) {
    this.directory = resolve(directory);
    this.key = createHash("sha256").update(secret).digest();
  }

  async save(data) {
    await mkdir(this.directory, { recursive: true, mode: 0o700 });
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
    const filename = `${randomUUID()}.bcimg`;
    const path = resolve(this.directory, filename);
    if (!path.startsWith(`${this.directory}/`)) throw new Error("Invalid private file path");
    await writeFile(path, Buffer.concat([iv, cipher.getAuthTag(), encrypted]), { mode: 0o600 });
    await chmod(path, 0o600);
    return filename;
  }

  async read(filename) {
    const path = this.path(filename);
    const contents = await readFile(path);
    if (contents.length < 29) throw new Error("Private image is corrupted");
    const decipher = createDecipheriv("aes-256-gcm", this.key, contents.subarray(0, 12));
    decipher.setAuthTag(contents.subarray(12, 28));
    return Buffer.concat([decipher.update(contents.subarray(28)), decipher.final()]);
  }

  async delete(filename) {
    if (!filename) return;
    await rm(this.path(filename), { force: true });
  }

  path(filename) {
    if (!/^[0-9a-f-]+\.bcimg$/i.test(filename)) throw new Error("Invalid private image reference");
    const path = resolve(this.directory, filename);
    if (!path.startsWith(`${this.directory}/`)) throw new Error("Invalid private image path");
    return path;
  }
}
