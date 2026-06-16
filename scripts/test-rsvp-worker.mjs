import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { onRequestPost } from "../functions/api/rsvp.js";

const db = new DatabaseSync(":memory:");
for (const migration of [
  "migrations/0001_signup.sql",
  "migrations/0002_signup_metrics.sql",
  "migrations/0003_events_rsvps.sql"
]) {
  db.exec(readFileSync(migration, "utf8"));
}

const env = {
  MCC_DB: {
    prepare(sql) {
      return new D1Statement(db.prepare(sql));
    }
  }
};

class D1Statement {
  constructor(statement) {
    this.statement = statement;
    this.values = [];
  }

  bind(...values) {
    this.values = values;
    return this;
  }

  first() {
    return this.statement.get(...this.values) || null;
  }

  run() {
    const result = this.statement.run(...this.values);
    return {
      success: true,
      meta: result
    };
  }
}

async function postRsvp(fields) {
  const body = new URLSearchParams({
    event: "first-session",
    source: "worker-test",
    ...fields
  });
  const request = new Request("https://www.marxcompute.club/api/rsvp", {
    method: "POST",
    body,
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    }
  });

  const deferred = [];
  const response = await onRequestPost({
    request,
    env,
    waitUntil(promise) {
      deferred.push(promise);
    }
  });
  await Promise.all(deferred);
  return {
    status: response.status,
    payload: await response.json()
  };
}

function all(sql) {
  return db.prepare(sql).all();
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

let result = await postRsvp({
  email: "rsvp-test@example.com",
  name_handle: "first handle"
});
assert(result.status === 200 && result.payload.ok, "initial RSVP failed");

result = await postRsvp({
  email: "RSVP-Test@example.com",
  name_handle: "second handle",
  community_opt_in: "1"
});
assert(result.status === 200 && result.payload.ok, "RSVP opt-in update failed");

result = await postRsvp({
  email: "rsvp-test@example.com",
  name_handle: "third handle"
});
assert(result.status === 200 && result.payload.ok, "RSVP idempotent update failed");

result = await postRsvp({
  email: "not-an-email"
});
assert(result.status === 400 && !result.payload.ok, "invalid email should fail");

const rows = all(`
  SELECT email, name_handle, community_opt_in, source
  FROM event_rsvps
`);
assert(rows.length === 1, `expected one RSVP row, got ${rows.length}`);
assert(rows[0].email === "rsvp-test@example.com", "email should be normalized");
assert(rows[0].name_handle === "third handle", "duplicate RSVP should update name/handle");
assert(rows[0].community_opt_in === 1, "community opt-in should not be downgraded");

const metrics = all(`
  SELECT event_type, count
  FROM signup_metric_rollups
  WHERE source = 'worker-test'
  ORDER BY event_type
`);
assert(metrics.some((row) => row.event_type === "rsvp_saved" && row.count === 3), "saved metric missing");
assert(metrics.some((row) => row.event_type === "rsvp_invalid_email" && row.count === 1), "invalid metric missing");

console.log(JSON.stringify({ ok: true, rows, metrics }, null, 2));
