# One customer deployment on GCP. Copied by `make tf-new`; DEPLOY is substituted
# with the directory name.
terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
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

  # State lives centrally, one object per deployment, so losing this working copy
  # never costs the ability to manage or destroy a customer's stack. GCS locks
  # state on its own; nothing extra to provision.
  backend "gcs" {
    bucket = "TF_STATE_BUCKET"
    prefix = "deployments/DEPLOY"
  }
}

# Credentials come from this deployment's terraform.tfvars, so each customer can
# sit in its own GCP project.
provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials != "" ? file(var.credentials) : null
}

module "moodle" {
  source = "../../modules/moodle-gcp"

  project_id        = var.project_id
  credentials       = var.credentials
  region            = var.region
  zone              = var.zone
  name              = var.name
  machine_type      = var.machine_type
  disk_gb           = var.disk_gb
  subnet_cidr       = var.subnet_cidr
  moodle_domain     = var.moodle_domain
  acme_email        = var.acme_email
  acme_staging      = var.acme_staging
  moodle_admin_user = var.moodle_admin_user
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  enable_apis       = var.enable_apis
}
