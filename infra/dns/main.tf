terraform {
  required_version = ">= 1.8.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {}

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

locals {
  domain = "marxcompute.club"
}

moved {
  from = cloudflare_dns_record.www_github_pages
  to   = cloudflare_dns_record.www_site
}

resource "cloudflare_d1_database" "mcc_signups" {
  account_id            = var.cloudflare_account_id
  name                  = "mcc-signups"
  primary_location_hint = "enam"
}

resource "cloudflare_pages_project" "mcc_site" {
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
      }
    }
  }
}

resource "cloudflare_pages_domain" "www" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.mcc_site.name
  name         = "www.${local.domain}"
}

resource "cloudflare_dns_record" "www_site" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${local.domain}"
  type    = "CNAME"
  content = "${cloudflare_pages_project.mcc_site.name}.pages.dev"
  ttl     = 1
  proxied = true
  comment = "Managed by OpenTofu: MCC Cloudflare Pages"
}

output "www_target" {
  value = {
    name    = cloudflare_dns_record.www_site.name
    type    = cloudflare_dns_record.www_site.type
    content = cloudflare_dns_record.www_site.content
    proxied = cloudflare_dns_record.www_site.proxied
  }
}

output "pages_project" {
  value = {
    name      = cloudflare_pages_project.mcc_site.name
    subdomain = cloudflare_pages_project.mcc_site.subdomain
    domains   = cloudflare_pages_project.mcc_site.domains
  }
}

output "d1_database" {
  value = {
    name = cloudflare_d1_database.mcc_signups.name
    id   = cloudflare_d1_database.mcc_signups.id
  }
}
