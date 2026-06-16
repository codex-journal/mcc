# MCC Signup And RSVP Flow

The signup form posts to `/api/signup`, a Cloudflare Pages Function under
`functions/api/signup.js`.

The first source of truth for the public announcement list and event RSVPs is
D1 via the `MCC_DB` binding. Resend sync is optional and only runs for the
announcement signup path when `RESEND_API_KEY` is present.

Public D1 deliberately uses `subscribers` and `signup_events` for the
announcement/update list. It does not use the id-01 `community_users` table.
The id-01 store is the canonical identity/community store; D1 is the public
intake and fallback collection ledger.

Event RSVPs use separate `mcc_events` and `event_rsvps` tables. An RSVP-only
record does not create an MCC identity account and does not subscribe the user
to broadcasts. The `event_rsvps.community_opt_in` flag means the user requested
an optional MCC microplatform invitation; a later id-01 sync job may consume
that consent and create or link a canonical community record.

## Local Test

Run these from the repo dev shell. The flake uses the Nix-packaged Wrangler so
local `workerd` runs correctly on NixOS.

```bash
nix develop
CI=true wrangler d1 migrations apply mcc-signups --local --config wrangler.local.jsonc --persist-to .wrangler/state-rsvp
wrangler pages dev . --binding SIGNUP_ENV=local --port 8788 --persist-to .wrangler/state-rsvp
```

In another shell:

```bash
node scripts/test-signup.mjs
node scripts/test-rsvp.mjs
node scripts/test-rsvp-worker.mjs
```

Open `http://127.0.0.1:8788` and submit the form to test it in-browser.
`test-rsvp-worker.mjs` imports the RSVP Pages Function directly and runs the
upsert path against an in-memory SQLite D1 shim. It is a fast logic test; it
does not replace a Wrangler Pages smoke test.

Wrangler Pages dev does not currently accept a custom Wrangler config path.
Use the checked-in default `wrangler.jsonc` binding for Pages smoke tests and
override only local env vars on the command line. `wrangler.local.jsonc`
remains useful for direct `wrangler d1 execute` checks against the local
`mcc-signups` database.

## Inspect Local D1

```bash
wrangler d1 execute mcc-signups --local --config wrangler.local.jsonc --command "SELECT email, status, source, resend_synced_at, sync_error FROM subscribers ORDER BY updated_at DESC LIMIT 10"
```

Inspect aggregate signup counters:

```bash
wrangler d1 execute mcc-signups --local --config wrangler.local.jsonc --command "SELECT day, event_type, source, count FROM signup_metric_rollups ORDER BY day DESC, event_type, source"
```

For a cleaner operator view, use:

```bash
scripts/d1-signups --local
scripts/d1-rsvps --local
scripts/d1-rsvps --local --config wrangler.jsonc --persist-to .wrangler/state-rsvp
```

## Inspect Remote D1

Remote signup inspection uses Wrangler and the production D1 binding from
`wrangler.jsonc`:

```bash
scripts/d1-signups
scripts/d1-signups --limit 100
scripts/d1-signups --json
scripts/d1-rsvps
scripts/d1-rsvps --limit 100
scripts/d1-rsvps --json
```

By default this prints status/source counts, recent subscriber rows, and recent
aggregate signup metrics. It does not select or print `page_referrer` or
`user_agent`.

Remote usage requires actual Cloudflare credentials with access to the MCC
account and the `mcc-signups` D1 database. A Wrangler login,
`CLOUDFLARE_API_TOKEN`, or the local secret broker can provide those credentials.
If `CLOUDFLARE_ACCOUNT_ID` is not set but `TF_VAR_cloudflare_account_id` is
available, the script exports it for Wrangler. If `CLOUDFLARE_API_TOKEN` is not
set but `TF_VAR_cloudflare_account_api_token` is available, it exports that
account token for Wrangler.

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

Current launch segment:

```text
MCC announcements
aa859afd-e0a1-401a-b8f7-f97fa63d4373
```

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

## Event RSVP Fields

The public RSVP record is:

```text
event_id
email
name_handle
status
community_opt_in
source
consent_at
created_at
updated_at
sync_status
sync_error
```

`event_rsvps` has a uniqueness constraint on `(event_id, email)`. Repeated RSVP
submissions update the existing row. If a user has already requested the
microplatform invitation, a later RSVP without the checkbox does not silently
remove that consent.

The current public event seed is:

```text
slug: first-session
title: First session
starts_at: 2026-06-25T23:00:00.000Z
location_label: NYC
```

Adjust event details through a source-controlled migration or explicit operator
SQL, not through the RSVP handler.

## Aggregate Signup Metrics

The signup function updates `signup_metric_rollups` through `context.waitUntil`.
These counters are for operational health, not attribution:

```text
signup_attempt
honeypot_hit
invalid_email
turnstile_fail
signup_saved
signup_save_failed
resend_sync_ok
resend_sync_fail
resend_sync_skipped
rsvp_attempt
rsvp_honeypot_hit
rsvp_invalid_email
rsvp_turnstile_fail
rsvp_unknown_event
rsvp_saved
rsvp_save_failed
```

The rollup key is `day`, `event_type`, and sanitized `source`. It does not store
IP addresses, full user-agent strings, or visitor IDs.

## Production Verification

The live launch path was verified with a browser signup after Turnstile,
Cloudflare Pages secrets, and Resend sync were enabled:

```text
email: personal Gmail plus-address test
resend_contact_id: populated
resend_synced_at: 2026-05-06T03:14:37.778Z
sync_error: null
```

An earlier test row retains a pre-fix Resend validation error from when the
worker sent undeclared contact properties. It is useful as an audit trail, not
as the current expected behavior.
