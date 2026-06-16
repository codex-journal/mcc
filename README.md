# Marx Compute Club

Static site scaffold for marxcompute.club.

## Local Shell

```bash
nix develop
```

## Prototypes

`prototypes/site-copy.html` is a standalone local page for comparing homepage
copy candidates. It is not deployed by `scripts/build-site`.

## Source Notes

Versioned source notes are rendered from `source-notes/*.org` into the public
`/notes/` route by `scripts/build-site`. Each rendered note gets a current
page, a source-hash-addressed version page, and JSON provenance with SHA-256
hashes for the Org source, rendered body, renderer source, `flake.lock`, and
build revision where available.

No source note is published until an `.org` file is added under `source-notes/`.

The fixture test renders `tests/fixtures/source-notes/sample.org` twice into
temporary directories and compares the outputs byte-for-byte:

```bash
scripts/test-source-notes
nix flake check
```

## Signup Flow

The homepage includes a minimal announcement signup form. Local signup testing
uses Cloudflare Pages Functions and D1:

```bash
CI=true wrangler d1 migrations apply mcc-signups --local --config wrangler.local.jsonc --persist-to .wrangler/state-rsvp
wrangler pages dev . --binding SIGNUP_ENV=local --port 8788 --persist-to .wrangler/state-rsvp
```

Then submit the form at `http://127.0.0.1:8788` or run:

```bash
node scripts/test-signup.mjs
node scripts/test-rsvp.mjs
node scripts/test-rsvp-worker.mjs
```

See `docs/signup.md` for provider sync and D1 notes.
See `docs/email.md` for Migadu mailbox setup.

## License

Source code, build scripts, Cloudflare Functions, and infrastructure code in
this repository are licensed under the GNU Affero General Public License v3.0
or later. See `LICENSE`.

Textual site content, posts, event copy, and documentation are licensed under
Creative Commons Attribution-ShareAlike 4.0 International unless otherwise
noted. See `LICENSES/CC-BY-SA-4.0.txt`.

Rendered story cards, artifact pages, and non-logo visual compositions generated
from this repository are also licensed under CC BY-SA 4.0 unless otherwise
noted.

MCC names, marks, logos, and source marks are identity assets. This repository
does not grant trademark rights or permission to imply endorsement,
affiliation, official status, or unrelated use.

Third-party logos, screenshots, service marks, product names, and referenced
marks remain property of their respective owners. They may appear here only for
identification, commentary, provenance, or documentation where applicable.

## Build

Cloudflare Pages is the only active public site deployment path. GitHub Pages
must remain disabled for this repository.

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
