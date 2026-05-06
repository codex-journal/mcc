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

## DNS

DNS is managed with OpenTofu under `infra/dns`.

For now, only `www.marxcompute.club` points at GitHub Pages. The apex
`marxcompute.club` is reserved for a future VPS.
