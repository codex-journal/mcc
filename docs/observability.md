# MCC Observability

MCC uses privacy-preserving observability for operational feedback, not
visitor profiling.

## Site Traffic

Cloudflare Web Analytics is managed in `infra/dns/main.tf` with
`cloudflare_web_analytics_site.mcc_site`.

The site is configured with:

```text
host:         marxcompute.club
auto_install: true
lite:         true
```

`auto_install` lets Cloudflare inject the Web Analytics beacon at the edge for
the proxied site, so the HTML does not contain a committed analytics token.
`lite` disables beacon injection for visitors from the EU.

Cloudflare Web Analytics should be treated as aggregate site telemetry:

- visits and page views
- paths
- referrer hosts
- country, device, browser, and OS dimensions
- page load timing and Core Web Vitals

It is not a signup attribution system, session replay system, or durable user
identity store.

## Signup Funnel

D1 is the canonical signup store. The next observability step is an aggregate
signup funnel counter that records operational outcomes without recording IP
addresses, full user-agent strings, or visitor IDs.

Target events:

```text
signup_attempt
honeypot_hit
invalid_email
turnstile_fail
signup_saved
resend_sync_ok
resend_sync_fail
```

## Email Delivery

Resend should only be used for list delivery and deliverability health. Keep
open and click tracking disabled. If webhooks are added, store only delivery
states such as delivered, bounced, complained, and unsubscribed.
