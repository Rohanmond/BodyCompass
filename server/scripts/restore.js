import { resolve } from "node:path";
import { configuredDatabasePath, restoreDatabase } from "../src/operations/databaseBackup.js";

try {
  process.loadEnvFile?.(".env");
} catch (error) {
  if (error?.code !== "ENOENT") throw error;
}

const source = process.argv[2];
const confirmed = process.argv.includes("--confirm");
if (!source || !confirmed) {
  console.error("Stop BodyCompass first, then run: npm run restore -- /absolute/path/backup.sqlite --confirm");
  process.exit(2);
}

const destination = configuredDatabasePath();
const result = await restoreDatabase(resolve(source), destination);
console.log(`Restored metadata database: ${destination}`);
console.log(result.previousPath ? `Previous database preserved at: ${result.previousPath}` : "No previous database existed.");
