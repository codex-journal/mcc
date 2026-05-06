const endpoint = process.env.SIGNUP_URL || "http://127.0.0.1:8788/api/signup";
const email = process.env.SIGNUP_EMAIL || `test+${Date.now()}@example.com`;

const body = new URLSearchParams({
  email,
  source: "local-test"
});

const response = await fetch(endpoint, {
  method: "POST",
  body,
  headers: {
    "Accept": "application/json",
    "Content-Type": "application/x-www-form-urlencoded"
  }
});

const payload = await response.json();
console.log(JSON.stringify({ status: response.status, email, payload }, null, 2));

if (!response.ok || !payload.ok) {
  process.exitCode = 1;
}
