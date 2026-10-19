terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}

# Allow images from this project's Artifact Registry when evaluation is
# PROJECT_SINGLETON_POLICY_ENFORCE. Default cluster mode is DISABLED until
# the operator mirrors the image and flips the variable.
resource "google_binary_authorization_policy" "this" {
  project = var.project_id

  default_admission_rule {
    evaluation_mode  = var.enforce ? "ALWAYS_DENY" : "ALWAYS_ALLOW"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  admission_whitelist_patterns {
    name_pattern = "${var.image_prefix}/**"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/cloud-sql-connectors/**"
  }

  admission_whitelist_patterns {
    name_pattern = "gke.gcr.io/**"
  }

  admission_whitelist_patterns {
    name_pattern = "ghcr.io/kedacore/**"
  }
}
