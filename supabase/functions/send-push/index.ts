import { createClient } from "npm:@supabase/supabase-js@2.99.2";

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
let cachedAccess: { token: string; until: number } | undefined;

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

async function accessToken(account: ServiceAccount): Promise<string> {
  if (cachedAccess && cachedAccess.until > Date.now()) return cachedAccess.token;
  const encoder = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);
  const encode = (data: unknown) => base64url(encoder.encode(JSON.stringify(data)));
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    iss: account.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned));
  const result = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${base64url(new Uint8Array(signature))}` }),
  });
  if (!result.ok) throw new Error("FCM_OAUTH_FAILED");
  const data = await result.json();
  cachedAccess = { token: data.access_token, until: Date.now() + 3300_000 };
  return cachedAccess.token;
}

// Custom hook authentication is validated by a service-role-only RPC against
// the secret in Vault before any tokens or notification data are returned.
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const secret = req.headers.get("x-push-secret");
  if (!secret || secret.length < 32) return new Response("Unauthorized", { status: 401 });
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
  let jobId: string | undefined;
  let claimed = false;
  try {
    jobId = (await req.json()).notification_id;
    if (!jobId || !/^[0-9a-f-]{36}$/i.test(jobId)) return new Response("Invalid notification", { status: 400 });
    const { data: job, error } = await db.rpc("claim_push_job", { job_id: jobId, webhook_secret: secret });
    if (error) return new Response("Unauthorized", { status: 401 });
    if (!job) return Response.json({ skipped: true });
    claimed = true;
    const tokens: string[] = job.tokens;
    if (tokens.length) {
      const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
      let account: ServiceAccount;
      if (raw) {
        account = JSON.parse(raw);
      } else {
        const { data: stored, error: vaultError } = await db.rpc("fcm_service_account");
        if (vaultError || !stored) throw new Error("FCM_SERVICE_ACCOUNT_NOT_CONFIGURED");
        account = stored;
      }
      const bearer = await accessToken(account);
      let retry = false;
      for (const token of tokens) {
        const result = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
          method: "POST", headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
          body: JSON.stringify({ message: {
            token, notification: { title: job.title, body: job.body },
            data: { notification_id: job.id, recipient_id: job.recipient_id, booking_id: job.booking_id ?? "", load_id: job.load_id ?? "" },
            android: { priority: "HIGH", ttl: "86400s", notification: { channel_id: "lorry_link_updates", tag: job.id, sound: "default" } },
          } }),
        });
        if (!result.ok) {
          const error = await result.json();
          const unregistered = error.error?.details?.some((detail: { errorCode?: string }) => detail.errorCode === "UNREGISTERED");
          if (unregistered) {
            await db.from("push_tokens").delete().eq("token", token);
          } else {
            retry = true;
          }
        }
      }
      if (retry) throw new Error("FCM_SEND_FAILED");
    }
    const { error: finishError } = await db.from("push_jobs").update({ state: "sent", last_error: null, updated_at: new Date().toISOString() }).eq("notification_id", jobId);
    if (finishError) throw new Error("PUSH_STATUS_SAVE_FAILED");
    return Response.json({ ok: true, devices: tokens.length });
  } catch (error) {
    const code = error instanceof Error && /^[A-Z_]+$/.test(error.message) ? error.message : "PUSH_DISPATCH_FAILED";
    if (claimed && jobId) await db.from("push_jobs").update({ state: "failed", last_error: code, updated_at: new Date().toISOString() }).eq("notification_id", jobId);
    console.error(code);
    return Response.json({ error: code }, { status: 500 });
  }
});
