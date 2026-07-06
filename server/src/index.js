import { createServer } from "node:http";
import { URL } from "node:url";
import { analyzeMeal } from "./routes/meals.js";
import { createChatAnswer } from "./routes/chat.js";
import { createGoalProjection } from "./routes/goal.js";
import { saveHealthSnapshot } from "./routes/healthSnapshots.js";

const port = Number(process.env.PORT ?? 8080);

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
    return send(response, 500, {
      error: "Internal server error",
      detail: error instanceof Error ? error.message : "Unknown error"
    });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`BodyCompass API listening on http://localhost:${port}`);
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
