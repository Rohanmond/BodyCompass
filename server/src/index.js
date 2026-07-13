import { createServer } from "node:http";
import { URL } from "node:url";
import { analyzeMeal } from "./routes/meals.js";
import { createChatAnswer } from "./routes/chat.js";
import { createGoalProjection } from "./routes/goal.js";
import { saveHealthSnapshot } from "./routes/healthSnapshots.js";
import { analyzeProgressCheckIn } from "./routes/progressCheckIns.js";
import { listHealthSnapshots } from "./routes/healthSnapshots.js";
import {
  deleteAccountData,
  deleteMealRecord,
  deleteProgressRecord,
  exportAccountData,
  saveMealRecord,
  saveProfile,
  saveProgressRecord,
  saveSchedule
} from "./routes/accountData.js";
import { authenticate } from "./lib/auth.js";

try {
  process.loadEnvFile?.(".env");
} catch (error) {
  if (error?.code !== "ENOENT") throw error;
}

if (process.env.NODE_ENV === "production") {
  if (!process.env.BODYCOMPASS_API_TOKEN) throw new Error("BODYCOMPASS_API_TOKEN is required in production");
  if (!process.env.BODYCOMPASS_STORAGE_SECRET) throw new Error("BODYCOMPASS_STORAGE_SECRET is required in production");
}

const port = Number(process.env.PORT ?? 8080);
const host = process.env.HOST ?? "127.0.0.1";
if (!["127.0.0.1", "localhost", "::1"].includes(host) && !process.env.BODYCOMPASS_API_TOKEN) {
  throw new Error("BODYCOMPASS_API_TOKEN is required when the server listens beyond localhost");
}

const routes = {
  "GET /health": async () => json({ ok: true, service: "bodycompass-server" }),
  "POST /api/meals/analyze": analyzeMeal,
  "POST /api/chat": createChatAnswer,
  "POST /api/goal/projection": createGoalProjection,
  "POST /api/health-snapshots": saveHealthSnapshot,
  "GET /api/health-snapshots": listHealthSnapshots,
  "POST /api/progress-check-ins/analyze": analyzeProgressCheckIn,
  "PUT /api/profile": saveProfile,
  "PUT /api/schedule": saveSchedule,
  "POST /api/meals/save": saveMealRecord,
  "DELETE /api/meals": deleteMealRecord,
  "POST /api/progress-check-ins/save": saveProgressRecord,
  "DELETE /api/progress-check-ins": deleteProgressRecord,
  "GET /api/data/export": exportAccountData,
  "DELETE /api/data": deleteAccountData
};

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? "/", `http://${request.headers.host}`);
    const routeKey = `${request.method} ${url.pathname}`;
    const handler = routes[routeKey];

    if (!handler) {
      return send(response, 404, { error: "Route not found" });
    }

    if (url.pathname.startsWith("/api/")) {
      const auth = authenticate(request);
      if (!auth.ok) return send(response, auth.status, auth.body);
      request.bodyCompassAuth = auth;
    }

    const result = await handler(request);
    return send(response, result.status ?? 200, result.body ?? result);
  } catch (error) {
    const status = Number.isInteger(error?.status) ? error.status : 500;
    return send(response, status, status === 500
      ? { error: "Internal server error" }
      : { error: error instanceof Error ? error.message : "Request failed" });
  }
});

server.listen(port, host, () => {
  console.log(`BodyCompass API listening on http://${host}:${port}`);
});

function send(response, status, body) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "access-control-allow-origin": "*"
  });
  response.end(JSON.stringify(body, null, 2));
}

function json(body, status = 200) {
  return { status, body };
}
