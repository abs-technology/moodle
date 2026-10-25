terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}

resource "google_artifact_registry_repository" "moodle" {
  location      = var.location
  repository_id = var.repository_id
  description   = "ABS Moodle images for GKE (mirrored from Docker Hub)"
  format        = "DOCKER"
  project       = var.project_id

  docker_config {
    immutable_tags = false
  }

  kms_key_name = var.cmek_key == "" ? null : var.cmek_key
}
