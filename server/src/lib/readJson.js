export async function readJson(request) {
  let raw = "";

  for await (const chunk of request) {
    raw += chunk;
  }

  if (!raw.trim()) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    const error = new Error("Request body must be valid JSON");
    error.status = 400;
    throw error;
  }
}
