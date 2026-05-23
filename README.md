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

## License

Code in this repository is licensed under the GNU Affero General Public License
v3.0 or later. See `LICENSE`.

Textual site content, posts, event copy, and documentation are licensed under
Creative Commons Attribution-ShareAlike 4.0 International unless otherwise
noted. See `LICENSES/CC-BY-SA-4.0.txt`.

MCC names, marks, and logos are identity assets. This repository does not grant
trademark rights or permission to imply endorsement, affiliation, or official
status for unrelated projects.

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

For now, `www.marxcompute.club` and `marxcompute.club` both serve the launch
site through Cloudflare Pages. The apex uses Cloudflare CNAME flattening, so it
can later be moved to a VPS by removing the Pages custom domain and replacing
the apex DNS record.
