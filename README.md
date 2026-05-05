# Marx Compute Club

Static site scaffold for marxcompute.club.

## Local Shell

```bash
nix develop
```

## DNS

DNS is managed with OpenTofu under `infra/dns`.

For now, only `www.marxcompute.club` points at GitHub Pages. The apex
`marxcompute.club` is reserved for a future VPS.
