import { createServer } from "node:http";
import { URL } from "node:url";
import { analyzeMeal } from "./routes/meals.js";
import { createChatAnswer } from "./routes/chat.js";
import { createGoalProjection } from "./routes/goal.js";
import { saveHealthSnapshot } from "./routes/healthSnapshots.js";

try {
  process.loadEnvFile?.(".env");
} catch (error) {
  if (error?.code !== "ENOENT") throw error;
}

const port = Number(process.env.PORT ?? 8080);
const host = process.env.HOST ?? "127.0.0.1";

const routes = {
  "GET /health": async () => json({ ok: true, service: "bodycompass-server" }),
  "POST /api/meals/analyze": analyzeMeal,
  "POST /api/chat": createChatAnswer,
  "POST /api/goal/projection": createGoalProjection,
  "POST /api/health-snapshots": saveHealthSnapshot
};

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url ?? "/", `http://${request.headers.host}`);
    const routeKey = `${request.method} ${url.pathname}`;
    const handler = routes[routeKey];

    if (!handler) {
      return send(response, 404, { error: "Route not found" });
    }

    const result = await handler(request);
    return send(response, result.status ?? 200, result.body ?? result);
  } catch (error) {
    const status = Number.isInteger(error?.status) ? error.status : 500;
    return send(response, status, {
      error: status === 500 ? "Internal server error" : error.message,
      detail: error instanceof Error ? error.message : "Unknown error"
    });
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
