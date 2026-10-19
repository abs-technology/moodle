terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}

resource "google_compute_security_policy" "this" {
  name        = "${var.name}-armor"
  description = "Cloud Armor for Moodle Global ALB"
  project     = var.project_id
  type        = "CLOUD_ARMOR"

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default allow"
  }

  rule {
    action   = "throttle"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_count
        interval_sec = 60
      }
    }
    description = "per-IP request throttle"
  }
}
