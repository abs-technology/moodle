# Credentials: Application Default Credentials only (no JSON key).
# Project / quota: injected from terraform/live/terraform.tfvars by make init.
provider "google" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
  region                = var.location
}
