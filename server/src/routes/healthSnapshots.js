import { readJson } from "../lib/readJson.js";
import { persistenceStore } from "../persistence/database.js";

export async function saveHealthSnapshot(request) {
  const body = await readJson(request);

  if (!body.date) {
    return {
      status: 400,
      body: { error: "date is required" }
    };
  }

  return {
    status: 201,
    body: persistenceStore().saveHealthSnapshot(request.bodyCompassAuth?.userId ?? "local-owner", body)
  };
}

export async function listHealthSnapshots(request) {
  return {
    status: 200,
    body: persistenceStore().listHealthSnapshots(request.bodyCompassAuth?.userId ?? "local-owner")
  };
}
