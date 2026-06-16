const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DEFAULT_EVENT_SLUG = "first-session";

export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: corsHeaders()
  });
}

export async function onRequestGet() {
  return json({ ok: true, service: "mcc-rsvp" });
}

export async function onRequestPost(context) {
  const { request, env } = context;

  if (!env.MCC_DB) {
    return json({ ok: false, error: "RSVP database is not configured." }, 500);
  }

  const payload = await readPayload(request);
  const email = String(payload.email || "").trim().toLowerCase();
  const nameHandle = sanitizeNameHandle(payload.name_handle || payload.name || "");
  const eventSlug = sanitizeSlug(payload.event || DEFAULT_EVENT_SLUG);
  const source = sanitizeToken(payload.source || "event-page");
  const honeypot = String(payload.company || "").trim();
  const communityOptIn = payload.community_opt_in === "1" ||
    payload.community_opt_in === "on" ||
    payload.community_opt_in === true;

  track(context, "rsvp_attempt", source);

  if (honeypot) {
    track(context, "rsvp_honeypot_hit", source);
    return json({ ok: true, message: "RSVP received." });
  }

  if (!EMAIL_PATTERN.test(email) || email.length > 320) {
    track(context, "rsvp_invalid_email", source);
    return json({ ok: false, error: "Enter a valid email." }, 400);
  }

  const turnstileResult = await verifyTurnstile(env, payload);
  if (!turnstileResult.ok) {
    track(context, "rsvp_turnstile_fail", source);
    return json({ ok: false, error: turnstileResult.error }, 400);
  }

  let event;
  try {
    event = await env.MCC_DB.prepare(`
      SELECT id, title
      FROM mcc_events
      WHERE slug = ?
      LIMIT 1
    `).bind(eventSlug).first();
  } catch {
    track(context, "rsvp_save_failed", source);
    return json({ ok: false, error: "RSVP database is not ready." }, 500);
  }

  if (!event) {
    track(context, "rsvp_unknown_event", source);
    return json({ ok: false, error: "Event is not available." }, 404);
  }

  const now = new Date().toISOString();
  const rsvpId = crypto.randomUUID();

  let result;
  try {
    result = await env.MCC_DB.prepare(`
      INSERT INTO event_rsvps (
        id,
        event_id,
        email,
        name_handle,
        status,
        community_opt_in,
        source,
        consent_at,
        created_at,
        updated_at
      )
      VALUES (?, ?, ?, ?, 'rsvp', ?, ?, ?, ?, ?)
      ON CONFLICT(event_id, email) DO UPDATE SET
        name_handle = excluded.name_handle,
        status = 'rsvp',
        community_opt_in = CASE
          WHEN event_rsvps.community_opt_in = 1 THEN 1
          ELSE excluded.community_opt_in
        END,
        source = excluded.source,
        consent_at = CASE
          WHEN excluded.community_opt_in = 1 AND event_rsvps.community_opt_in = 0
            THEN excluded.consent_at
          ELSE event_rsvps.consent_at
        END,
        updated_at = excluded.updated_at,
        sync_status = CASE
          WHEN excluded.community_opt_in = 1 AND event_rsvps.community_opt_in = 0
            THEN 'pending'
          ELSE event_rsvps.sync_status
        END,
        sync_error = CASE
          WHEN excluded.community_opt_in = 1 AND event_rsvps.community_opt_in = 0
            THEN NULL
          ELSE event_rsvps.sync_error
        END
    `).bind(
      rsvpId,
      event.id,
      email,
      nameHandle,
      communityOptIn ? 1 : 0,
      source,
      now,
      now,
      now
    ).run();
  } catch {
    track(context, "rsvp_save_failed", source);
    return json({ ok: false, error: "Could not save RSVP." }, 500);
  }

  if (!result.success) {
    track(context, "rsvp_save_failed", source);
    return json({ ok: false, error: "Could not save RSVP." }, 500);
  }

  track(context, "rsvp_saved", source);

  return json({
    ok: true,
    message: communityOptIn
      ? "RSVP received. Microplatform invite requested."
      : "RSVP received.",
    event: {
      id: event.id,
      title: event.title
    }
  });
}

async function readPayload(request) {
  const contentType = request.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return request.json();
  }

  const formData = await request.formData();
  return Object.fromEntries(formData.entries());
}

async function verifyTurnstile(env, payload) {
  if (!env.TURNSTILE_SECRET_KEY) {
    return { ok: true };
  }

  const token = payload["cf-turnstile-response"];
  if (!token) {
    return { ok: false, error: "Verification failed." };
  }

  const body = new FormData();
  body.append("secret", env.TURNSTILE_SECRET_KEY);
  body.append("response", token);

  const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body
  });
  const result = await response.json();

  return result.success ? { ok: true } : { ok: false, error: "Verification failed." };
}

function track(context, eventType, source) {
  const promise = recordMetric(context.env?.MCC_DB, eventType, source).catch(() => {});
  if (context.waitUntil) {
    context.waitUntil(promise);
  }
}

async function recordMetric(db, eventType, source) {
  if (!db) {
    return;
  }

  const now = new Date().toISOString();
  const day = now.slice(0, 10);

  await db.prepare(`
    INSERT INTO signup_metric_rollups (day, event_type, source, count, updated_at)
    VALUES (?, ?, ?, 1, ?)
    ON CONFLICT(day, event_type, source) DO UPDATE SET
      count = count + 1,
      updated_at = excluded.updated_at
  `).bind(day, sanitizeToken(eventType), sanitizeToken(source || "event-page"), now).run();
}

function sanitizeSlug(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 80) || DEFAULT_EVENT_SLUG;
}

function sanitizeToken(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 80) || "event-page";
}

function sanitizeNameHandle(value) {
  const cleaned = String(value).trim().replace(/\s+/g, " ");
  return cleaned ? cleaned.slice(0, 160) : null;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store"
    }
  });
}
