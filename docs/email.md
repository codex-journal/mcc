# MCC Email

Use Migadu for human mailbox email on `marxcompute.club`. Do not use Migadu
for bulk broadcasts.

Use Resend for announcement/broadcast delivery. Resend is authenticated for
sending from `marxcompute.club`; Migadu remains responsible for normal inbound
mail at the root domain.

## Migadu Account

Create a Migadu account and API token. The API token is a user token, not a
domain DNS token.

```bash
export MIGADU_USER="you@example.com"
export MIGADU_TOKEN="..."
```

Create the domain in Migadu:

```bash
scripts/migadu-create-domain
```

Fetch Migadu's expected DNS records:

```bash
scripts/migadu-records | jq
```

Migadu currently expects this root verification TXT:

```text
hosted-email-verify=4oneiln0
```

That value is represented in OpenTofu as `migadu_dns_verification`.
If Migadu rotates it later, apply the new value through OpenTofu:

```bash
export TF_VAR_migadu_dns_verification="value-from-migadu"
cd infra/dns
tofu plan
tofu apply
```

The OpenTofu stack already manages the standard Migadu MX, SPF, DKIM, and
DMARC records.

## Mailboxes

Create an initial mailbox:

```bash
export MIGADU_MAILBOX="hello"
export MIGADU_MAILBOX_NAME="Marx Compute Club"
export MIGADU_MAILBOX_PASSWORD="..."
scripts/migadu-create-mailbox
```

Launch addresses:

```text
source@marxcompute.club
material@marxcompute.club
admin@marxcompute.club
```

Use `source@marxcompute.club` for direct public correspondence and
`material@marxcompute.club` for broadcasts, theoretical notes, and event
announcements. Keep `admin@marxcompute.club` for provider accounts and private
administration.

## Client Settings

Migadu webmail:

```text
https://webmail.migadu.com
```

Standard client settings:

```text
IMAP: imap.migadu.com:993 TLS
SMTP: smtp.migadu.com:465 TLS
POP:  pop.migadu.com:995 TLS
```

## Resend

Resend DNS is represented in OpenTofu:

```text
TXT resend._domainkey.marxcompute.club
MX  send.marxcompute.club -> feedback-smtp.us-east-1.amazonses.com
TXT send.marxcompute.club -> v=spf1 include:amazonses.com ~all
```

The `send.marxcompute.club` MX record is only for Resend bounce handling. It
does not replace the Migadu root MX records.

After DNS verification, create a Resend API key with enough permission to manage
contacts and segments. `sending_access` is not sufficient for the signup sync
path.

Useful local helpers:

```bash
export RESEND_API_KEY="re_..."
scripts/resend-list-segments
scripts/resend-create-segment
```

The launch broadcast segment is:

```text
MCC announcements
aa859afd-e0a1-401a-b8f7-f97fa63d4373
```

Use `material@marxcompute.club` as the public broadcast sender/reply identity
unless the editorial naming changes:

```text
Marx Compute Club <material@marxcompute.club>
```

Create broadcast drafts through the API rather than the dashboard:

```bash
export RESEND_API_KEY="re_..."
scripts/resend-create-broadcast \
  --subject "First MCC notice" \
  --name "First MCC notice" \
  --text path/to/body.txt
```

The helper defaults to the `MCC announcements` segment and
`Marx Compute Club <material@marxcompute.club>`. It creates a draft unless
`--send` is passed. The raw Resend HTTP API currently expects `segment_id`;
their SDK examples use `segmentId`.
