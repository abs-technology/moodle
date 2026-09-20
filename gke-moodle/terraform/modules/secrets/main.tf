terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9"
    }
  }
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "random_password" "moodle_admin" {
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "db" {
  secret_id = "${var.name}-db-password"
  project   = var.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db" {
  secret      = google_secret_manager_secret.db.id
  secret_data = random_password.db.result
}

resource "google_secret_manager_secret" "admin" {
  secret_id = "${var.name}-admin-password"
  project   = var.project_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin" {
  secret      = google_secret_manager_secret.admin.id
  secret_data = random_password.moodle_admin.result
}
