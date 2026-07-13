import { resolve } from "node:path";
import { backupDatabase, configuredDatabasePath } from "../src/operations/databaseBackup.js";

try {
  process.loadEnvFile?.(".env");
} catch (error) {
  if (error?.code !== "ENOENT") throw error;
}

const destination = process.argv[2];
if (!destination) {
  console.error("Usage: npm run backup -- /absolute/path/bodycompass-YYYY-MM-DD.sqlite");
  process.exit(2);
}

const source = configuredDatabasePath();
const manifest = await backupDatabase(source, resolve(destination));
console.log(`Created photo-free metadata backup: ${resolve(destination)}`);
console.log(`SHA-256: ${manifest.sha256}`);
