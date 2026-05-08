terraform {
  required_version = ">= 1.8.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_account_api_token != "" ? var.cloudflare_account_api_token : null
  alias     = "account"
}

provider "cloudflare" {
  api_token = var.cloudflare_zone_api_token != "" ? var.cloudflare_zone_api_token : null
  alias     = "zone"
}

provider "cloudflare" {}

variable "cloudflare_account_api_token" {
  description = "Optional account-scoped Cloudflare API token for Pages and D1. Falls back to provider env if empty."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_api_token" {
  description = "Optional zone-scoped Cloudflare API token for DNS. Falls back to provider env if empty."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for marxcompute.club."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the Pages project and D1 database."
  type        = string
}

variable "cloudflare_pages_project_name" {
  description = "Cloudflare Pages project name for the MCC site."
  type        = string
  default     = "marxcompute-club"
}

variable "migadu_dns_verification" {
  description = "Optional Migadu root TXT verification value from the Migadu domain records API."
  type        = string
  default     = "hosted-email-verify=4oneiln0"
}

variable "migadu_dmarc_policy" {
  description = "DMARC policy for Migadu mail. Start at quarantine, then tighten to reject after testing."
  type        = string
  default     = "quarantine"

  validation {
    condition     = contains(["none", "quarantine", "reject"], var.migadu_dmarc_policy)
    error_message = "migadu_dmarc_policy must be one of none, quarantine, or reject."
  }
}

locals {
  domain = "marxcompute.club"
}

moved {
  from = cloudflare_dns_record.www_github_pages
  to   = cloudflare_dns_record.www_site
}

resource "cloudflare_d1_database" "mcc_signups" {
  provider              = cloudflare.account
  account_id            = var.cloudflare_account_id
  name                  = "mcc-signups"
  primary_location_hint = "enam"

  lifecycle {
    ignore_changes = [read_replication]
  }
}

resource "cloudflare_turnstile_widget" "signup" {
  provider   = cloudflare.account
  account_id = var.cloudflare_account_id
  name       = "MCC signup"
  domains = [
    "${var.cloudflare_pages_project_name}.pages.dev",
    local.domain,
    "www.${local.domain}",
  ]
  mode   = "managed"
  region = "world"
}

resource "cloudflare_pages_project" "mcc_site" {
  provider          = cloudflare.account
  account_id        = var.cloudflare_account_id
  name              = var.cloudflare_pages_project_name
  production_branch = "main"

  deployment_configs = {
    production = {
      compatibility_date = "2026-05-05"

      d1_databases = {
        MCC_DB = {
          id = cloudflare_d1_database.mcc_signups.id
        }
      }

      env_vars = {
        SIGNUP_ENV = {
          type  = "plain_text"
          value = "production"
        }
        TURNSTILE_SITE_KEY = {
          type  = "plain_text"
          value = cloudflare_turnstile_widget.signup.sitekey
        }
        TURNSTILE_SECRET_KEY = {
          type  = "secret_text"
          value = cloudflare_turnstile_widget.signup.secret
        }
      }
    }

    preview = {
      compatibility_date = "2026-05-05"

      d1_databases = {
        MCC_DB = {
          id = cloudflare_d1_database.mcc_signups.id
        }
      }

      env_vars = {
        SIGNUP_ENV = {
          type  = "plain_text"
          value = "preview"
        }
        TURNSTILE_SITE_KEY = {
          type  = "plain_text"
          value = cloudflare_turnstile_widget.signup.sitekey
        }
        TURNSTILE_SECRET_KEY = {
          type  = "secret_text"
          value = cloudflare_turnstile_widget.signup.secret
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [deployment_configs]
  }
}

resource "cloudflare_pages_domain" "www" {
  provider     = cloudflare.account
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.mcc_site.name
  name         = "www.${local.domain}"
}

resource "cloudflare_pages_domain" "apex" {
  provider     = cloudflare.account
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.mcc_site.name
  name         = local.domain
}

resource "cloudflare_web_analytics_site" "mcc_site" {
  provider     = cloudflare.account
  account_id   = var.cloudflare_account_id
  host         = local.domain
  zone_tag     = var.cloudflare_zone_id
  auto_install = true
  enabled      = true
  lite         = true
}

resource "cloudflare_dns_record" "www_site" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = "www.${local.domain}"
  type     = "CNAME"
  content  = "${cloudflare_pages_project.mcc_site.name}.pages.dev"
  ttl      = 1
  proxied  = true
  comment  = "Managed by OpenTofu: MCC Cloudflare Pages"
}

resource "cloudflare_dns_record" "apex_site" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = local.domain
  type     = "CNAME"
  content  = "${cloudflare_pages_project.mcc_site.name}.pages.dev"
  ttl      = 1
  proxied  = true
  comment  = "Managed by OpenTofu: MCC Cloudflare Pages apex"
}

resource "cloudflare_dns_record" "migadu_mx_primary" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = local.domain
  type     = "MX"
  content  = "aspmx1.migadu.com"
  priority = 10
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Migadu primary MX"
}

resource "cloudflare_dns_record" "migadu_mx_secondary" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = local.domain
  type     = "MX"
  content  = "aspmx2.migadu.com"
  priority = 20
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Migadu secondary MX"
}

resource "cloudflare_dns_record" "migadu_spf" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = local.domain
  type     = "TXT"
  content  = "v=spf1 include:spf.migadu.com -all"
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Migadu SPF"
}

resource "cloudflare_dns_record" "migadu_dkim" {
  provider = cloudflare.zone
  for_each = toset(["key1", "key2", "key3"])

  zone_id = var.cloudflare_zone_id
  name    = "${each.key}._domainkey.${local.domain}"
  type    = "CNAME"
  content = "${each.key}.${local.domain}._domainkey.migadu.com"
  ttl     = 1
  proxied = false
  comment = "Managed by OpenTofu: Migadu DKIM ${each.key}"
}

resource "cloudflare_dns_record" "migadu_dmarc" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = "_dmarc.${local.domain}"
  type     = "TXT"
  content  = "v=DMARC1; p=${var.migadu_dmarc_policy};"
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Migadu DMARC"
}

resource "cloudflare_dns_record" "migadu_dns_verification" {
  provider = cloudflare.zone
  count    = var.migadu_dns_verification == "" ? 0 : 1

  zone_id = var.cloudflare_zone_id
  name    = local.domain
  type    = "TXT"
  content = var.migadu_dns_verification
  ttl     = 1
  proxied = false
  comment = "Managed by OpenTofu: Migadu domain verification"
}

resource "cloudflare_dns_record" "resend_dkim" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = "resend._domainkey.${local.domain}"
  type     = "TXT"
  content  = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCqUJCDM0Zp6dTGc2zGUylfyQN5ExpD/E8gDS1ATG0QiLCl7GDburYkTT/tkAY2wZpXEDObwbv0vkyN2DX9DaDcUy9eti2L7pu+t3KvCJ7R51pAHHu/jJtv3abG2mUO9rXZ3e6wtqCeKvRo645pBTcXDm1P3P8Vu4h25S0TxnT+WQIDAQAB"
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Resend DKIM"
}

resource "cloudflare_dns_record" "resend_bounce_mx" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = "send.${local.domain}"
  type     = "MX"
  content  = "feedback-smtp.us-east-1.amazonses.com"
  priority = 10
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Resend bounce MX"
}

resource "cloudflare_dns_record" "resend_bounce_spf" {
  provider = cloudflare.zone
  zone_id  = var.cloudflare_zone_id
  name     = "send.${local.domain}"
  type     = "TXT"
  content  = "v=spf1 include:amazonses.com ~all"
  ttl      = 1
  proxied  = false
  comment  = "Managed by OpenTofu: Resend bounce SPF"
}

output "www_target" {
  value = {
    name    = cloudflare_dns_record.www_site.name
    type    = cloudflare_dns_record.www_site.type
    content = cloudflare_dns_record.www_site.content
    proxied = cloudflare_dns_record.www_site.proxied
  }
}

output "apex_target" {
  value = {
    name    = cloudflare_dns_record.apex_site.name
    type    = cloudflare_dns_record.apex_site.type
    content = cloudflare_dns_record.apex_site.content
    proxied = cloudflare_dns_record.apex_site.proxied
  }
}

output "pages_project" {
  value = {
    name      = cloudflare_pages_project.mcc_site.name
    subdomain = cloudflare_pages_project.mcc_site.subdomain
    domains   = cloudflare_pages_project.mcc_site.domains
  }
}

output "turnstile" {
  value = {
    name    = cloudflare_turnstile_widget.signup.name
    sitekey = cloudflare_turnstile_widget.signup.sitekey
  }
}

output "web_analytics" {
  value = {
    host         = cloudflare_web_analytics_site.mcc_site.host
    auto_install = cloudflare_web_analytics_site.mcc_site.auto_install
    eu_lite      = cloudflare_web_analytics_site.mcc_site.lite
  }
}

output "d1_database" {
  value = {
    name = cloudflare_d1_database.mcc_signups.name
    id   = cloudflare_d1_database.mcc_signups.id
  }
}

output "migadu_dns" {
  value = {
    mx = [
      {
        priority = cloudflare_dns_record.migadu_mx_primary.priority
        content  = cloudflare_dns_record.migadu_mx_primary.content
      },
      {
        priority = cloudflare_dns_record.migadu_mx_secondary.priority
        content  = cloudflare_dns_record.migadu_mx_secondary.content
      },
    ]
    spf   = cloudflare_dns_record.migadu_spf.content
    dmarc = cloudflare_dns_record.migadu_dmarc.content
    dkim  = { for key, record in cloudflare_dns_record.migadu_dkim : key => record.content }
  }
}

output "resend_dns" {
  value = {
    dkim = {
      name    = cloudflare_dns_record.resend_dkim.name
      content = cloudflare_dns_record.resend_dkim.content
    }
    bounce_mx = {
      name     = cloudflare_dns_record.resend_bounce_mx.name
      content  = cloudflare_dns_record.resend_bounce_mx.content
      priority = cloudflare_dns_record.resend_bounce_mx.priority
    }
    bounce_spf = {
      name    = cloudflare_dns_record.resend_bounce_spf.name
      content = cloudflare_dns_record.resend_bounce_spf.content
    }
  }
}
