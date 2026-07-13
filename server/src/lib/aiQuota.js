import { persistenceStore } from "../persistence/database.js";

const defaults = { meal: 10, chat: 30, progress: 3 };

export function quotaLimits(environment = process.env) {
  return {
    meal: positiveInteger(environment.BODYCOMPASS_DAILY_MEAL_AI_LIMIT, defaults.meal),
    chat: positiveInteger(environment.BODYCOMPASS_DAILY_CHAT_AI_LIMIT, defaults.chat),
    progress: positiveInteger(environment.BODYCOMPASS_DAILY_PROGRESS_AI_LIMIT, defaults.progress)
  };
}

export function consumeAIQuota(request, kind) {
  const userId = request.bodyCompassAuth?.userId;
  if (!userId) return { status: 401, body: { error: "Sign in is required" } };
  const limit = quotaLimits()[kind];
  const usage = persistenceStore().consumeAIUsage(userId, kind, limit);
  if (usage.allowed) return null;
  return {
    status: 429,
    body: {
      error: `Daily ${kind} AI limit reached`,
      usage,
      resetsAt: nextUTCDay()
    }
  };
}

export function usageSummary(request) {
  const userId = request.bodyCompassAuth?.userId;
  const limits = quotaLimits();
  const rows = new Map(persistenceStore().aiUsage(userId).map((row) => [row.kind, row.units]));
  return {
    status: 200,
    body: {
      day: new Date().toISOString().slice(0, 10),
      resetsAt: nextUTCDay(),
      usage: Object.fromEntries(Object.entries(limits).map(([kind, limit]) => {
        const used = rows.get(kind) ?? 0;
        return [kind, { used, limit, remaining: Math.max(0, limit - used) }];
      }))
    }
  };
}

function positiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function nextUTCDay() {
  const date = new Date();
  date.setUTCHours(24, 0, 0, 0);
  return date.toISOString();
}
