# MCC DNS

This manages only the temporary GitHub Pages hostname:

```text
www.marxcompute.club -> codex-journal.github.io
```

The apex `marxcompute.club` is intentionally left unmanaged here so it can later point to a VPS.

## Apply

Provide secrets out of band:

```bash
export CLOUDFLARE_API_TOKEN="$(sops -d --extract '["cloudflare-marxcompute-token"]' /path/to/private/secrets.yaml)"
export TF_VAR_cloudflare_zone_id="..."
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
Zone / Zone / Read
Zone / DNS / Edit
```

for the `marxcompute.club` zone only.

