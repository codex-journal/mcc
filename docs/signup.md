# MCC Signup Flow

The signup form posts to `/api/signup`, a Cloudflare Pages Function under
`functions/api/signup.js`.

The first source of truth is D1 via the `MCC_DB` binding. Resend sync is
optional and only runs when `RESEND_API_KEY` is present.

## Local Test

Run these from the repo dev shell. The flake uses the Nix-packaged Wrangler so
local `workerd` runs correctly on NixOS.

```bash
nix develop
wrangler d1 migrations apply mcc-signups --local --config wrangler.local.jsonc
wrangler pages dev . --config wrangler.local.jsonc
```

In another shell:

```bash
node scripts/test-signup.mjs
```

Open `http://127.0.0.1:8788` and submit the form to test it in-browser.

## Inspect Local D1

```bash
wrangler d1 execute mcc-signups --local --config wrangler.local.jsonc --command "SELECT email, status, source, resend_synced_at, sync_error FROM subscribers ORDER BY updated_at DESC LIMIT 10"
```

## Remote Migration

Production D1 is configured in `wrangler.jsonc`:

```bash
export CLOUDFLARE_ACCOUNT_ID="$TF_VAR_cloudflare_account_id"
wrangler d1 migrations apply mcc-signups --remote --config wrangler.jsonc
```

Passing `CLOUDFLARE_ACCOUNT_ID` avoids Wrangler calling `/memberships` to infer
the account, which fails for narrowly scoped Cloudflare tokens.

## Resend Sync

Set these as Cloudflare environment variables/secrets once Resend is configured:

```text
RESEND_API_KEY
RESEND_SEGMENT_ID
```

`RESEND_SEGMENT_ID` is optional, but broadcasts are normally sent to a segment,
so the launch path should create one segment for MCC announcements and add
signups to it.

## Turnstile

Set `TURNSTILE_SECRET_KEY` when the form includes a Turnstile widget. Without
that variable, local signup skips bot verification.

## Canonical Subscriber Fields

The portable subscriber record is:

```text
email
status
source
page_referrer
user_agent
consent_at
created_at
updated_at
resend_contact_id
resend_synced_at
sync_error
```

Do not treat Resend as canonical. Resend is the delivery layer; D1 is the owned
list.
