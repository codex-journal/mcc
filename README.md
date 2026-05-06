# Marx Compute Club

Static site scaffold for marxcompute.club.

## Local Shell

```bash
nix develop
```

## Signup Flow

The homepage includes a minimal announcement signup form. Local signup testing
uses Cloudflare Pages Functions and D1:

```bash
wrangler d1 migrations apply mcc-signups --local --config wrangler.local.jsonc
wrangler pages dev . --config wrangler.local.jsonc
```

Then submit the form at `http://127.0.0.1:8788` or run:

```bash
node scripts/test-signup.mjs
```

See `docs/signup.md` for provider sync and D1 notes.
See `docs/email.md` for Migadu mailbox setup.

## Build

Cloudflare Pages deploys the static assets from `dist` and uploads Pages
Functions from the repo-level `functions` directory:

```bash
scripts/build-site
export CLOUDFLARE_ACCOUNT_ID="$TF_VAR_cloudflare_account_id"
wrangler d1 migrations apply mcc-signups --remote --config wrangler.jsonc
wrangler pages deploy dist --project-name marxcompute-club --branch main
```

## Cloudflare Infra

Cloudflare Pages, D1, the `www` custom domain, and DNS are managed with
OpenTofu under `infra/dns`.

For now, `www.marxcompute.club` is the canonical launch site. The apex
`marxcompute.club` is configured as an originless Cloudflare redirect to `www`
so typed URLs work while preserving the future option to point the apex at a
VPS.
