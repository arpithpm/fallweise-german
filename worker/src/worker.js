const TOKEN_URL = "https://generativelanguage.googleapis.com/v1alpha/auth_tokens";
const ALLOWED_ORIGINS = new Set([
  "https://arpithpm.github.io",
  "http://127.0.0.1:4173",
  "http://localhost:4173"
]);

function headers(origin) {
  return {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "access-control-allow-origin": ALLOWED_ORIGINS.has(origin) ? origin : "https://arpithpm.github.io",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-allow-methods": "POST, OPTIONS",
    "vary": "Origin"
  };
}

function json(value, status, origin) {
  return new Response(JSON.stringify(value), { status, headers: headers(origin) });
}

async function validSupabaseUser(request, env) {
  const authorization = request.headers.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) return false;
  const response = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: { authorization, apikey: env.SUPABASE_PUBLISHABLE_KEY }
  });
  return response.ok;
}

async function ephemeralToken(apiKey) {
  const now = Date.now();
  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify({
      uses: 1,
      expireTime: new Date(now + 30 * 60_000).toISOString(),
      newSessionExpireTime: new Date(now + 2 * 60_000).toISOString()
    })
  });
  const body = await response.json();
  if (!response.ok || !body.name) throw new Error("Gemini rejected the session");
  return { token: body.name, expiresAt: body.expireTime };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("origin") || "";
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: headers(origin) });
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true }, 200, origin);
    if (url.pathname !== "/api/gemini/session" || request.method !== "POST") return json({ error: "Not found" }, 404, origin);
    if (!ALLOWED_ORIGINS.has(origin)) return json({ error: "Origin not allowed" }, 403, origin);
    if (!(await validSupabaseUser(request, env))) return json({ error: "Sign in required" }, 401, origin);
    try {
      const token = await ephemeralToken(env.GEMINI_API_KEY);
      return json({ ...token, model: env.GEMINI_LIVE_MODEL }, 200, origin);
    } catch (error) {
      console.error("Voice session failed", error instanceof Error ? error.message : "unknown");
      return json({ error: "Unable to create a voice session" }, 502, origin);
    }
  }
};
