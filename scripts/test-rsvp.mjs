const endpoint = process.env.RSVP_URL || "http://127.0.0.1:8788/api/rsvp";
const email = process.env.RSVP_EMAIL || `rsvp+${Date.now()}@example.com`;
const nameHandle = process.env.RSVP_NAME_HANDLE || "local test";
const communityOptIn = process.env.RSVP_COMMUNITY_OPT_IN === "1";

const body = new URLSearchParams({
  email,
  name_handle: nameHandle,
  event: "first-session",
  source: "local-test"
});

if (communityOptIn) {
  body.set("community_opt_in", "1");
}

const response = await fetch(endpoint, {
  method: "POST",
  body,
  headers: {
    "Accept": "application/json",
    "Content-Type": "application/x-www-form-urlencoded"
  }
});

const responseText = await response.text();
let payload;
try {
  payload = JSON.parse(responseText);
} catch {
  payload = { ok: false, error: responseText };
}

console.log(JSON.stringify({ status: response.status, email, payload }, null, 2));

if (!response.ok || !payload.ok) {
  process.exitCode = 1;
}
