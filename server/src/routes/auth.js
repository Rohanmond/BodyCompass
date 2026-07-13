import { createHmac, randomBytes, randomInt, randomUUID, scrypt as scryptCallback, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { bearerToken, hashSessionToken } from "../lib/auth.js";
import { readJson } from "../lib/readJson.js";
import { persistenceStore } from "../persistence/database.js";
import { sendEmailLoginCode } from "../services/emailDelivery.js";

const scrypt = promisify(scryptCallback);
const sessionDurationMs = 30 * 24 * 60 * 60 * 1_000;
const attempts = new Map();

export async function requestEmailCode(request) {
  if (!allowAttempt(request)) return tooManyRequests();
  const body = await readJson(request, 10_000);
  const email = normalizeEmail(body.email);
  if (!validEmail(email)) return badRequest("Enter a valid email address");

  const latest = persistenceStore().latestEmailCode(email);
  if (latest && Date.now() - Date.parse(latest.createdAt) < 60_000) {
    return { status: 429, body: { error: "Wait one minute before requesting another code" } };
  }

  const id = randomUUID();
  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const expiresAt = new Date(Date.now() + 10 * 60_000).toISOString();
  persistenceStore().createEmailCode({ id, email, codeHash: hashEmailCode(id, code), expiresAt });
  const delivery = await sendEmailLoginCode({ to: email, code, challengeId: id });
  return {
    status: 202,
    body: {
      challengeId: id,
      expiresAt,
      message: "If the address can receive mail, a sign-in code is on its way.",
      ...(delivery.developmentCode ? { developmentCode: delivery.developmentCode } : {})
    }
  };
}

export async function verifyEmailCode(request) {
  if (!allowAttempt(request)) return tooManyRequests();
  const body = await readJson(request, 10_000);
  const challenge = typeof body.challengeId === "string" ? persistenceStore().emailCode(body.challengeId) : null;
  const code = typeof body.code === "string" ? body.code.trim() : "";
  if (!challenge || !/^\d{6}$/.test(code) || challenge.consumedAt || challenge.attempts >= 5 || Date.parse(challenge.expiresAt) <= Date.now()) {
    return { status: 401, body: { error: "The code is incorrect or has expired" } };
  }

  const expected = Buffer.from(challenge.codeHash, "hex");
  const supplied = Buffer.from(hashEmailCode(challenge.id, code), "hex");
  if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
    persistenceStore().recordEmailCodeFailure(challenge.id);
    return { status: 401, body: { error: "The code is incorrect or has expired" } };
  }
  if (!persistenceStore().consumeEmailCode(challenge.id)) {
    return { status: 401, body: { error: "The code is incorrect or has expired" } };
  }

  let account = persistenceStore().accountByEmail(challenge.email);
  const isNewAccount = !account;
  if (!account) {
    account = persistenceStore().createAccount({
      email: challenge.email,
      displayName: displayNameFromEmail(challenge.email),
      emailVerifiedAt: new Date().toISOString()
    });
  } else {
    persistenceStore().markEmailVerified(account.id);
  }
  return sessionResponse(account, isNewAccount ? 201 : 200);
}

export async function register(request) {
  if (!allowAttempt(request)) return tooManyRequests();
  const body = await readJson(request, 20_000);
  const email = normalizeEmail(body.email);
  const displayName = typeof body.displayName === "string" ? body.displayName.trim() : "";
  const passwordError = validatePassword(body.password);

  if (!validEmail(email)) return badRequest("Enter a valid email address");
  if (displayName.length < 2 || displayName.length > 60) return badRequest("Name must contain 2 to 60 characters");
  if (passwordError) return badRequest(passwordError);
  if (persistenceStore().accountByEmail(email)) return conflict("An account with this email already exists");

  const credentials = await passwordCredentials(body.password);
  let user;
  try {
    user = persistenceStore().createAccount({ email, displayName, ...credentials });
  } catch (error) {
    if (String(error?.message).includes("UNIQUE")) return conflict("An account with this email already exists");
    throw error;
  }
  return sessionResponse(user, 201);
}

export async function login(request) {
  if (!allowAttempt(request)) return tooManyRequests();
  const body = await readJson(request, 20_000);
  const email = normalizeEmail(body.email);
  const password = typeof body.password === "string" ? body.password : "";
  const account = persistenceStore().accountByEmail(email);

  if (!account || !await passwordMatches(password, account.passwordSalt, account.passwordHash)) {
    return { status: 401, body: { error: "Email or password is incorrect" } };
  }
  return sessionResponse(account);
}

export function currentAccount(request) {
  return {
    status: 200,
    body: {
      user: {
        id: request.bodyCompassAuth.userId,
        email: request.bodyCompassAuth.email,
        displayName: request.bodyCompassAuth.displayName,
        emailVerified: request.bodyCompassAuth.emailVerified
      }
    }
  };
}

export function logout(request) {
  const token = bearerToken(request);
  if (token) persistenceStore().deleteSession(hashSessionToken(token));
  return { status: 204, body: {} };
}

async function passwordCredentials(password) {
  const passwordSalt = randomBytes(16).toString("hex");
  const derived = await scrypt(password, passwordSalt, 64);
  return { passwordSalt, passwordHash: Buffer.from(derived).toString("hex") };
}

async function passwordMatches(password, salt, expectedHash) {
  if (!salt || !expectedHash) return false;
  const expected = Buffer.from(expectedHash, "hex");
  const actual = Buffer.from(await scrypt(password, salt, expected.length));
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

function hashEmailCode(challengeId, code) {
  const secret = process.env.BODYCOMPASS_AUTH_SECRET
    ?? process.env.BODYCOMPASS_STORAGE_SECRET
    ?? process.env.BODYCOMPASS_API_TOKEN
    ?? "bodycompass-local-development-only";
  return createHmac("sha256", secret).update(`email-login:${challengeId}:${code}`).digest("hex");
}

function displayNameFromEmail(email) {
  const value = email.split("@")[0].replace(/[._-]+/g, " ").trim();
  return value ? value.slice(0, 60).replace(/\b\w/g, (letter) => letter.toUpperCase()) : "BodyCompass User";
}

function sessionResponse(user, status = 200) {
  const token = randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + sessionDurationMs).toISOString();
  persistenceStore().createSession(user.id, hashSessionToken(token), expiresAt);
  return {
    status,
    body: {
      token,
      expiresAt,
      user: { id: user.id, email: user.email, displayName: user.displayName, emailVerified: Boolean(user.emailVerifiedAt) }
    }
  };
}

function normalizeEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function validEmail(value) {
  return value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function validatePassword(value) {
  if (typeof value !== "string" || value.length < 10) return "Password must contain at least 10 characters";
  if (value.length > 128) return "Password must contain at most 128 characters";
  if (!/[A-Za-z]/.test(value) || !/[0-9]/.test(value)) return "Password must include a letter and a number";
  return null;
}

function allowAttempt(request) {
  const key = String(request.headers?.["x-forwarded-for"] ?? request.socket?.remoteAddress ?? "unknown").split(",")[0].trim();
  const now = Date.now();
  const recent = (attempts.get(key) ?? []).filter((timestamp) => now - timestamp < 15 * 60 * 1_000);
  recent.push(now);
  attempts.set(key, recent);
  return recent.length <= 20;
}

function badRequest(error) { return { status: 400, body: { error } }; }
function conflict(error) { return { status: 409, body: { error } }; }
function tooManyRequests() { return { status: 429, body: { error: "Too many sign-in attempts. Try again in 15 minutes." } }; }
