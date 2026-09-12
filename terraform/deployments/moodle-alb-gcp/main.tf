# One customer Moodle behind a GCP Global ALB. Copied by `make new-alb`.
# Independent of `make new-traefik` / `make apply-traefik` and `make new-ip`.
terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Backend nằm ở backend.tf, do scripts/tf-deployments.sh sinh ra ở lần chạy đầu.
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials != "" ? file(var.credentials) : null
}

module "moodle" {
  source = "../../modules/moodle-gcp"

  project_id             = var.project_id
  credentials            = var.credentials
  region                 = var.region
  zone                   = var.zone
  name                   = var.name
  machine_type           = var.machine_type
  disk_gb                = var.disk_gb
  subnet_cidr            = var.subnet_cidr
  moodle_domain          = var.moodle_domain
  acme_email             = var.acme_email
  acme_staging           = var.acme_staging
  moodle_admin_user      = var.moodle_admin_user
  ssh_allowed_cidrs      = var.ssh_allowed_cidrs
  enable_apis            = var.enable_apis
  timezone               = var.timezone
  snapshot_weekly        = var.snapshot_weekly
  snapshot_retain_weeks  = var.snapshot_retain_weeks
  vm_deletion_protection = var.vm_deletion_protection
  enable_global_alb      = true
}
