import { isAbsolute, resolve } from "node:path";

const LOCAL_HOSTS = new Set(["127.0.0.1", "localhost", "::1"]);

export function loadConfig(environment = process.env) {
  const production = environment.NODE_ENV === "production";
  const port = Number(environment.PORT ?? 8080);
  const host = environment.HOST ?? "127.0.0.1";
  const dataDirectory = resolve(environment.BODYCOMPASS_DATA_DIR ?? "server-data");
  const errors = [];

  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    errors.push("PORT must be an integer from 1 to 65535");
  }

  const token = environment.BODYCOMPASS_API_TOKEN ?? "";
  const tokenIsStrong = token.length >= 32 && !isPlaceholder(token);
  if (!LOCAL_HOSTS.has(host) && !tokenIsStrong) {
    errors.push("BODYCOMPASS_API_TOKEN must contain at least 32 characters when listening beyond localhost");
  }

  if (production) {
    if (!tokenIsStrong) errors.push("BODYCOMPASS_API_TOKEN must contain at least 32 non-placeholder characters in production");
    if (!environment.BODYCOMPASS_USER_ID || environment.BODYCOMPASS_USER_ID === "local-owner" || isPlaceholder(environment.BODYCOMPASS_USER_ID)) {
      errors.push("BODYCOMPASS_USER_ID must be a stable non-default value in production");
    }
    if (!environment.BODYCOMPASS_DATA_DIR || !isAbsolute(environment.BODYCOMPASS_DATA_DIR)) {
      errors.push("BODYCOMPASS_DATA_DIR must be an absolute durable-volume path in production");
    }
    if (environment.BODYCOMPASS_DATABASE_PATH && !isAbsolute(environment.BODYCOMPASS_DATABASE_PATH)) {
      errors.push("BODYCOMPASS_DATABASE_PATH must be absolute when configured in production");
    }
    if (!environment.OPENAI_API_KEY) errors.push("OPENAI_API_KEY is required in production");
    if (!environment.GEMINI_API_KEY) errors.push("GEMINI_API_KEY is required in production");
  }

  return {
    production,
    port,
    host,
    dataDirectory,
    errors,
    valid: errors.length === 0
  };
}

function isPlaceholder(value) {
  return value.startsWith("replace-") || value.startsWith("change-");
}

export function assertValidConfig(environment = process.env) {
  const config = loadConfig(environment);
  if (!config.valid) {
    throw new Error(`Invalid BodyCompass configuration:\n- ${config.errors.join("\n- ")}`);
  }
  return config;
}
