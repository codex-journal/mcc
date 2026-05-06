# MCC Cloudflare Infra

This stack manages the Cloudflare pieces needed for the launch site:

```text
Cloudflare Pages project: marxcompute-club
D1 database:              mcc-signups
Turnstile widget:         MCC signup
custom domain:            www.marxcompute.club
DNS:                      www.marxcompute.club -> marxcompute-club.pages.dev
Redirect:                 marxcompute.club -> https://www.marxcompute.club
Mail DNS:                 Migadu MX/SPF/DKIM/DMARC
```

The apex `marxcompute.club` uses an originless proxied `A` record
(`192.0.2.1`) plus a Cloudflare Single Redirect. This keeps typed apex URLs
working now while leaving a clean future migration path: remove the redirect
rule and replace the dummy apex `A` record with the VPS address.

## Apply

Provide secrets out of band.

If Cloudflare lets you create one token with both account and zone policies, you
can keep using `CLOUDFLARE_API_TOKEN`:

```bash
export CLOUDFLARE_API_TOKEN="$(sops -d --extract '["cloudflare-marxcompute-token"]' /path/to/private/secrets.yaml)"
export TF_VAR_cloudflare_account_id="..."
export TF_VAR_cloudflare_zone_id="..."
```

If Cloudflare will not let one token include both account and zone access, use
two tokens instead:

```bash
export TF_VAR_cloudflare_account_api_token="$(sops -d --extract '["cloudflare-mcc-account-token"]' /path/to/private/secrets.yaml)"
export TF_VAR_cloudflare_zone_api_token="$(sops -d --extract '["cloudflare-mcc-zone-token"]' /path/to/private/secrets.yaml)"
export TF_VAR_cloudflare_account_id="..."
export TF_VAR_cloudflare_zone_id="..."
```

To find the account ID with the token:

```bash
curl -sS https://api.cloudflare.com/client/v4/accounts \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq '.result[] | {name, id}'
```

Then:

```bash
nix develop
cd infra/dns
tofu init
tofu plan
tofu apply
```

The account token should be scoped to:

```text
Account / Pages / Write      (shown as Edit in some Cloudflare UI)
Account / D1 / Write         (shown as Edit in some Cloudflare UI)
Account / Turnstile / Write  (shown as Edit in some Cloudflare UI)
```

The zone token should be scoped to:

```text
Zone / Zone / Read
Zone / DNS / Write           (shown as Edit in some Cloudflare UI)
Zone / Single Redirect / Write
```

Cloudflare may show `Single Redirect / Edit` in the dashboard and
`Dynamic URL Redirects Write` in API docs for the same ruleset-backed redirect
path.

Limit the zone token to `marxcompute.club`, and limit the account token to the
Cloudflare account whose ID is in `TF_VAR_cloudflare_account_id`.

If D1 creation returns `401 Unauthorized`, the token is usually still only
zone-scoped. The D1 API is account-scoped:

```text
/client/v4/accounts/:account_id/d1/database
```

So the token must include account permissions, not only DNS/zone permissions.

To enable Migadu domain verification, set the optional root TXT value returned
by Migadu:

```bash
export TF_VAR_migadu_dns_verification="..."
```

## Deploy

After `tofu apply`, run the database migration and deploy the static site plus
Pages Function from the repo root:

```bash
cd ../..
scripts/build-site
export CLOUDFLARE_ACCOUNT_ID="$TF_VAR_cloudflare_account_id"
wrangler d1 migrations apply mcc-signups --remote --config wrangler.jsonc
wrangler pages deploy dist --project-name marxcompute-club --branch main
```

Pages deployment configuration is partially bootstrapped by OpenTofu, but
runtime secrets such as `RESEND_API_KEY` and `RESEND_SEGMENT_ID` are managed by
Wrangler. The `cloudflare_pages_project` resource ignores deployment config
drift so later DNS/ruleset applies do not delete manually-set Pages secrets.

Then test:

```bash
curl -I https://www.marxcompute.club
curl -I https://marxcompute.club
curl -sS https://www.marxcompute.club/api/signup
SIGNUP_URL=https://www.marxcompute.club/api/signup node scripts/test-signup.mjs
```
