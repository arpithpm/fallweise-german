import { AccessToken } from "livekit-server-sdk";
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

async function audio(request, env, key, origin) {
  if (!/^[a-f0-9]{64}\.wav$/.test(key)) return json({ error: "Invalid audio key" }, 400, origin);
  const object = await env.AUDIO.get(key, { range: request.headers });
  if (!object) return json({ error: "Audio not found" }, 404, origin);

  const responseHeaders = new Headers();
  object.writeHttpMetadata(responseHeaders);
  responseHeaders.set("etag", object.httpEtag);
  responseHeaders.set("content-type", "audio/wav");
  responseHeaders.set("cache-control", "public, max-age=31536000, immutable");
  responseHeaders.set("accept-ranges", "bytes");
  responseHeaders.set("access-control-allow-origin", ALLOWED_ORIGINS.has(origin) ? origin : "*");
  responseHeaders.set("cross-origin-resource-policy", "cross-origin");
  return new Response(request.method === "HEAD" ? null : object.body, { headers: responseHeaders });
}

async function supabaseUser(request, env) {
  const authorization = request.headers.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) return null;
  const response = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: { authorization, apikey: env.SUPABASE_PUBLISHABLE_KEY }
  });
  return response.ok ? response.json() : null;
}

async function liveKitCredentials(user, env) {
  const roomName = `fallweise-${crypto.randomUUID()}`;
  const token = new AccessToken(env.LIVEKIT_API_KEY, env.LIVEKIT_API_SECRET, {
    identity: `learner-${user.id}`,
    name: user.user_metadata?.name || "Fallweise learner",
    ttl: "15m"
  });
  token.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true
  });
  token.roomConfig = {
    agents: [{ agentName: "fallweise-livekit-agent", metadata: "" }]
  };
  return {
    server_url: env.LIVEKIT_URL,
    participant_token: await token.toJwt(),
    room_name: roomName
  };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("origin") || "";
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: headers(origin) });
    const url = new URL(request.url);
    if (url.pathname === "/health") return json({ ok: true }, 200, origin);
    if (url.pathname.startsWith("/audio/") && (request.method === "GET" || request.method === "HEAD")) {
      return audio(request, env, url.pathname.slice("/audio/".length), origin);
    }
    if (url.pathname !== "/api/livekit/session" || request.method !== "POST") return json({ error: "Not found" }, 404, origin);
    // Native clients do not send a browser Origin header. They are still
    // protected by the Supabase bearer-token verification below.
    if (origin && !ALLOWED_ORIGINS.has(origin)) return json({ error: "Origin not allowed" }, 403, origin);
    const user = await supabaseUser(request, env);
    if (!user) return json({ error: "Sign in required" }, 401, origin);
    try {
      return json(await liveKitCredentials(user, env), 201, origin);
    } catch (error) {
      console.error("LiveKit session failed", error instanceof Error ? error.message : "unknown");
      return json({ error: "Unable to create a voice session" }, 502, origin);
    }
  }
};
