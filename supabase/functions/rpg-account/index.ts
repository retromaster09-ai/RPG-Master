const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-region",
};
const uuid = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
const usernamePattern = /^[a-z0-9][a-z0-9_.-]{2,23}$/;
type Json = Record<string, unknown>;

function json(data: Json, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function setting(dict: string, legacy: string): string {
  const configured = Deno.env.get(dict);
  if (configured) {
    const { default: key } = JSON.parse(configured);
    if (typeof key === "string" && key) return key;
  }
  const fallback = Deno.env.get(legacy);
  if (!fallback) throw new Error("Missing project API configuration");
  return fallback;
}

const url = Deno.env.get("SUPABASE_URL")!;
const publicKey = setting("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
const serviceKey = setting("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
const encoder = new TextEncoder();

function upstream(path: string, key: string, body?: Json, authorization?: string, method?: string) {
  const headers: Record<string, string> = { apikey: key };
  if (authorization) headers.Authorization = authorization;
  else if (key.startsWith("eyJ")) headers.Authorization = `Bearer ${key}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  return fetch(url + path, {
    method: method ?? (body === undefined ? "GET" : "POST"),
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(8000),
  });
}

async function account(action: string, actor: string | null, data: Json = {}): Promise<Json> {
  const response = await upstream("/rest/v1/rpc/rpg_account", serviceKey, {
    p_action: action, p_actor: actor, p_data: data,
  });
  if (response.status === 403) return { error: "not_authorized" };
  if (!response.ok) throw new Error("Account database operation failed");
  return await response.json();
}

async function getActor(authorization: string | null): Promise<string | null> {
  if (!authorization || !/^Bearer [A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+){2}$/.test(authorization)) {
    return null;
  }
  const response = await upstream("/auth/v1/user", publicKey, undefined, authorization);
  if (!response.ok) return null;
  const actor = (await response.json()).id;
  return typeof actor === "string" && uuid.test(actor) ? actor : null;
}

function hex(bytes: Uint8Array) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hash(code: string) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(code))));
}

function field(input: Json, key: string) {
  return typeof input[key] === "string" ? input[key] as string : "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "invalid_method" }, 405);
  let input: Json;
  try {
    if (Number(req.headers.get("content-length")) > 8192) {
      return json({ error: "invalid_request" }, 413);
    }
    const body = await req.text();
    if (body.length > 8192) return json({ error: "invalid_request" }, 413);
    input = JSON.parse(body);
    if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error();
  } catch {
    return json({ error: "invalid_request" }, 400);
  }

  const action = field(input, "action");
  const username = field(input, "username").trim().toLowerCase();
  const password = field(input, "password");
  try {
    if (action === "register") {
      if (!usernamePattern.test(username)) return json({ error: "invalid_username" }, 400);
      if (password.length < 8 || encoder.encode(password).length > 72) {
        return json({ error: "invalid_password" }, 400);
      }
      const slot = await upstream("/rest/v1/rpc/rpg_take_registration_slot", serviceKey, {});
      if (!slot.ok) throw new Error("Registration limit unavailable");
      if (await slot.json() !== true) return json({ error: "registration_limited" }, 429);

      const target = await account("target", null, { username });
      if (target.user_id) return json({ error: "username_taken" }, 409);
      const created = await upstream("/auth/v1/admin/users", serviceKey, {
        email: `rpg-${crypto.randomUUID()}@accounts.rpgmaster.invalid`,
        email_confirm: true,
        password,
        app_metadata: { rpg_registration_username: username },
      });
      if (!created.ok) {
        const current = await account("target", null, { username });
        if (current.user_id) return json({ error: "username_taken" }, 409);
        return json({ error: "registration_failed" }, 502);
      }
      const user = await created.json();
      const profile = await account("target", null, { username });
      if (typeof user.id !== "string" || profile.user_id !== user.id) {
        return json({ error: "registration_failed" }, 502);
      }
      return json({ ok: true }, 201);
    }
    if (action === "login") {
      if (!usernamePattern.test(username) || !password || encoder.encode(password).length > 1024) {
        return json({ error: "invalid_credentials" }, 401);
      }
      const target = await account("target", null, { username });
      let email = "unregistered-rpg-user@example.invalid";
      if (typeof target.user_id === "string" && uuid.test(target.user_id)) {
        const user = await upstream(`/auth/v1/admin/users/${target.user_id}`, serviceKey);
        if (!user.ok) throw new Error("Auth lookup failed");
        const data = await user.json();
        if (typeof data.email === "string") email = data.email;
      }
      const response = await upstream("/auth/v1/token?grant_type=password", publicKey, { email, password });
      if (!response.ok || !target.user_id) return json({ error: "invalid_credentials" }, 401);
      const session = await response.json();
      if (session.user?.id !== target.user_id) return json({ error: "invalid_credentials" }, 401);
      return json({ access_token: session.access_token, refresh_token: session.refresh_token });
    }
    if (action === "request") {
      if (usernamePattern.test(username)) await account("request", null, { username });
      return json({ ok: true });
    }
    if (action === "recover") {
      const normalized = field(input, "code").replace(/[\s-]/g, "").toLowerCase();
      if (!usernamePattern.test(username) || !/^[a-f0-9]{20}$/.test(normalized)) {
        return json({ error: "invalid_code" }, 400);
      }
      if (password.length < 8 || encoder.encode(password).length > 72) {
        return json({ error: "invalid_password" }, 400);
      }
      const target = await account("claim", null, { username, hash: await hash(normalized) });
      if (typeof target.user_id !== "string" || !uuid.test(target.user_id)) {
        return json({ error: "invalid_code" }, 400);
      }
      const response = await upstream(`/auth/v1/admin/users/${target.user_id}`, serviceKey, { password }, undefined, "PUT");
      if (!response.ok) return json({ error: "reset_failed" }, 502);
      return json({ ok: true });
    }

    if (!["settings", "setup", "approve", "backup"].includes(action)) {
      return json({ error: "invalid_request" }, 400);
    }
    const actor = await getActor(req.headers.get("Authorization"));
    if (!actor) return json({ error: "not_authorized" }, 401);
    if (action === "settings") return json(await account("settings", actor));
    if (action === "setup") {
      const campaign = input.campaign_id;
      if (!usernamePattern.test(username) ||
          (campaign != null && (typeof campaign !== "string" || !uuid.test(campaign)))) {
        return json({ error: "invalid_request" }, 400);
      }
      const result = await account(action, actor, { username, campaign_id: campaign ?? null });
      return json(result, result.error === "username_taken" ? 409 : result.error ? 403 : 200);
    }

    const requestId = field(input, "request_id");
    if (action === "approve" && !uuid.test(requestId)) return json({ error: "invalid_request" }, 400);
    const code = hex(crypto.getRandomValues(new Uint8Array(10)));
    const result = await account(action, actor, { request_id: requestId, hash: await hash(code) });
    if (result.ok !== true) return json({ error: "not_authorized" }, 403);
    return json({ code: code.toUpperCase().match(/.{5}/g)!.join("-") });
  } catch {
    // Never return or log request bodies, passwords, codes, or tokens.
    return json({ error: "unavailable" }, 503);
  }
});
