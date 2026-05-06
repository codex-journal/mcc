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

Resend's current broadcast model uses global contacts plus segments. The older
audience API still exists in their docs but is deprecated; use segments for MCC
announcement routing.

Create or retrieve the launch segment:

```bash
export RESEND_API_KEY="re_..."
scripts/resend-create-segment
```

The output `id` is the value for `RESEND_SEGMENT_ID`.

Set these as Cloudflare Pages secrets once Resend is configured:

```text
RESEND_API_KEY
RESEND_SEGMENT_ID
```

`RESEND_API_KEY` must be able to create contacts and add them to segments.
Resend's documented key choices are currently `full_access` and
`sending_access`; `sending_access` is not enough for signup sync. Scope the key
to this worker operationally by using it only as a Cloudflare Pages secret.

The worker posts accepted signups to `POST /contacts`. When
`RESEND_SEGMENT_ID` is present it creates the contact with
`segments: [{ id: RESEND_SEGMENT_ID }]`; if the contact already exists, it adds
the existing email to that segment.

Do not send signup metadata as Resend contact properties unless those properties
have already been created in Resend. D1 remains the canonical store for signup
source, referrer, and user-agent metadata.

```bash
export CLOUDFLARE_ACCOUNT_ID="$TF_VAR_cloudflare_account_id"
wrangler pages secret put RESEND_API_KEY --project-name marxcompute-club
wrangler pages secret put RESEND_SEGMENT_ID --project-name marxcompute-club
```

Redeploy after setting secrets:

```bash
scripts/build-site
wrangler pages deploy dist --project-name marxcompute-club --branch main
```

## Turnstile

Turnstile is managed in OpenTofu with `cloudflare_turnstile_widget.signup`.
The Cloudflare Pages project receives:

```text
TURNSTILE_SITE_KEY
TURNSTILE_SECRET_KEY
```

The frontend fetches `/api/config` to get the public site key. The signup
function verifies `cf-turnstile-response` when `TURNSTILE_SECRET_KEY` exists.
Without that variable, local signup skips bot verification.

The public site key is also pinned in `wrangler.jsonc` for direct Pages
deployments. The secret key stays in Cloudflare Pages project configuration and
is not committed.

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
