export async function sendEmailLoginCode({ to, code, challengeId }) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    if (process.env.NODE_ENV !== "production") return { mode: "development", developmentCode: code };
    const error = new Error("Email sign-in is not configured yet");
    error.status = 503;
    throw error;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
      "idempotency-key": `bodycompass-login-${challengeId}`
    },
    body: JSON.stringify({
      from: process.env.BODYCOMPASS_EMAIL_FROM ?? "BodyCompass <onboarding@resend.dev>",
      to: [to],
      subject: `${code} is your BodyCompass sign-in code`,
      text: `Your BodyCompass sign-in code is ${code}. It expires in 10 minutes and can be used once. If you did not request this code, ignore this email.`,
      html: `<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#15201d;max-width:520px;margin:auto"><h1 style="font-size:24px">BodyCompass</h1><p>Use this one-time code to sign in:</p><p style="font-size:34px;font-weight:700;letter-spacing:8px">${code}</p><p>This code expires in 10 minutes and can be used once.</p><p style="color:#66736f;font-size:13px">If you did not request this code, you can ignore this email.</p></div>`
    })
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error(`Resend delivery failed (${response.status}): ${detail.slice(0, 240)}`);
    const error = new Error("We could not send the sign-in email. Please try again shortly.");
    error.status = 502;
    throw error;
  }
  return { mode: "resend" };
}
