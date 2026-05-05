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

locals {
  domain = "marxcompute.club"
}

resource "cloudflare_dns_record" "www_github_pages" {
  zone_id = var.cloudflare_zone_id
  name    = "www.${local.domain}"
  type    = "CNAME"
  content = "codex-journal.github.io"
  ttl     = 1
  proxied = false
  comment = "Managed by OpenTofu: MCC GitHub Pages"
}

output "www_target" {
  value = {
    name    = cloudflare_dns_record.www_github_pages.name
    type    = cloudflare_dns_record.www_github_pages.type
    content = cloudflare_dns_record.www_github_pages.content
    proxied = cloudflare_dns_record.www_github_pages.proxied
  }
}

