# MCC Cloudflare Infra

This stack manages the Cloudflare pieces needed for the launch site:

```text
Cloudflare Pages project: marxcompute-club
D1 database:              mcc-signups
custom domain:            www.marxcompute.club
DNS:                      www.marxcompute.club -> marxcompute-club.pages.dev
```

The apex `marxcompute.club` is intentionally left unmanaged here so it can later point to a VPS.

## Apply

Provide secrets out of band:

```bash
export CLOUDFLARE_API_TOKEN="$(sops -d --extract '["cloudflare-marxcompute-token"]' /path/to/private/secrets.yaml)"
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

The Cloudflare token should be scoped to:

```text
Account / Cloudflare Pages / Edit
Account / D1 / Edit
Zone / Zone / Read
Zone / DNS / Edit
```

Limit the zone permissions to `marxcompute.club`.

## Deploy

After `tofu apply`, run the database migration and deploy the static site plus
Pages Function:

```bash
nix develop
scripts/build-site
wrangler d1 migrations apply mcc-signups --remote
wrangler pages deploy dist --project-name marxcompute-club --branch main
```

Then test:

```bash
curl -I https://www.marxcompute.club
curl -sS https://www.marxcompute.club/api/signup
SIGNUP_URL=https://www.marxcompute.club/api/signup node scripts/test-signup.mjs
```
