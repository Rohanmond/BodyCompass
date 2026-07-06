import { readJson } from "../lib/readJson.js";

const snapshots = [];

export async function saveHealthSnapshot(request) {
  const body = await readJson(request);

  if (!body.date) {
    return {
      status: 400,
      body: { error: "date is required" }
    };
  }

  const snapshot = {
    id: `${body.date}-${Date.now()}`,
    ...body,
    createdAt: new Date().toISOString()
  };

  snapshots.push(snapshot);

  return {
    status: 201,
    body: snapshot
  };
}
