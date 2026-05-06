const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: corsHeaders()
  });
}

export async function onRequestGet() {
  return json({ ok: true, service: "mcc-signup" });
}

export async function onRequestPost(context) {
  const { request, env } = context;

  if (!env.MCC_DB) {
    return json({ ok: false, error: "Signup database is not configured." }, 500);
  }

  const payload = await readPayload(request);
  const email = String(payload.email || "").trim().toLowerCase();
  const source = sanitizeToken(payload.source || "site");
  const honeypot = String(payload.company || "").trim();

  if (honeypot) {
    return json({ ok: true, message: "You are on the list." });
  }

  if (!EMAIL_PATTERN.test(email) || email.length > 320) {
    return json({ ok: false, error: "Enter a valid email." }, 400);
  }

  const turnstileResult = await verifyTurnstile(env, payload);
  if (!turnstileResult.ok) {
    return json({ ok: false, error: turnstileResult.error }, 400);
  }

  const now = new Date().toISOString();
  const subscriberId = crypto.randomUUID();
  const eventId = crypto.randomUUID();
  const metadata = {
    source,
    path: header(request, "referer"),
    userAgent: header(request, "user-agent")
  };

  const result = await env.MCC_DB.batch([
    env.MCC_DB.prepare(`
      INSERT INTO subscribers (
        id,
        email,
        status,
        source,
        page_referrer,
        user_agent,
        consent_at,
        created_at,
        updated_at
      )
      VALUES (?, ?, 'subscribed', ?, ?, ?, ?, ?, ?)
      ON CONFLICT(email) DO UPDATE SET
        status = 'subscribed',
        source = excluded.source,
        page_referrer = excluded.page_referrer,
        user_agent = excluded.user_agent,
        updated_at = excluded.updated_at
    `).bind(
      subscriberId,
      email,
      source,
      metadata.path,
      metadata.userAgent,
      now,
      now,
      now
    ),
    env.MCC_DB.prepare(`
      INSERT INTO signup_events (id, email, event_type, payload, created_at)
      VALUES (?, ?, 'signup', ?, ?)
    `).bind(eventId, email, JSON.stringify(metadata), now)
  ]);

  if (!result.every((entry) => entry.success)) {
    return json({ ok: false, error: "Could not save signup." }, 500);
  }

  const sync = await syncResend(env, email, metadata);
  if (sync.status === "synced") {
    await markSynced(env.MCC_DB, email, sync.contactId || null);
  } else if (sync.status === "failed") {
    await markSyncError(env.MCC_DB, email, sync.error);
  }

  return json({
    ok: true,
    message: "You are on the list.",
    sync: sync.status
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

async function syncResend(env, email, metadata) {
  if (!env.RESEND_API_KEY) {
    return { status: "skipped" };
  }

  try {
    const contactPayload = {
      email,
      unsubscribed: false,
      properties: {
        mcc_source: metadata.source,
        mcc_referrer: metadata.path || "",
        mcc_user_agent: metadata.userAgent || ""
      }
    };

    if (env.RESEND_SEGMENT_ID) {
      contactPayload.segments = [{ id: env.RESEND_SEGMENT_ID }];
    }

    const createResponse = await fetch("https://api.resend.com/contacts", {
      method: "POST",
      headers: resendHeaders(env),
      body: JSON.stringify(contactPayload)
    });

    let contactId = null;
    if (createResponse.ok) {
      const created = await createResponse.json();
      contactId = created.id || null;
    } else if (createResponse.status !== 409) {
      return { status: "failed", error: await responseError(createResponse) };
    }

    if (env.RESEND_SEGMENT_ID && createResponse.status === 409) {
      const segmentResponse = await fetch(
        `https://api.resend.com/contacts/${encodeURIComponent(email)}/segments/${env.RESEND_SEGMENT_ID}`,
        {
          method: "POST",
          headers: resendHeaders(env),
          body: "{}"
        }
      );

      if (!segmentResponse.ok && segmentResponse.status !== 409) {
        return { status: "failed", error: await responseError(segmentResponse) };
      }
    }

    return { status: "synced", contactId };
  } catch (error) {
    return { status: "failed", error: error.message || "Resend sync failed." };
  }
}

async function markSynced(db, email, contactId) {
  await db.prepare(`
    UPDATE subscribers
    SET resend_contact_id = COALESCE(?, resend_contact_id),
        resend_synced_at = ?,
        sync_error = NULL,
        updated_at = ?
    WHERE email = ?
  `).bind(contactId, new Date().toISOString(), new Date().toISOString(), email).run();
}

async function markSyncError(db, email, error) {
  await db.prepare(`
    UPDATE subscribers
    SET sync_error = ?,
        updated_at = ?
    WHERE email = ?
  `).bind(String(error).slice(0, 1000), new Date().toISOString(), email).run();
}

function resendHeaders(env) {
  return {
    "Authorization": `Bearer ${env.RESEND_API_KEY}`,
    "Content-Type": "application/json"
  };
}

async function responseError(response) {
  const text = await response.text();
  return text || `${response.status} ${response.statusText}`;
}

function sanitizeToken(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 80) || "site";
}

function header(request, name) {
  return request.headers.get(name) || null;
}

function json(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(),
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Accept"
  };
}
