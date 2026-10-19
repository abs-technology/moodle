# Credentials: ADC. Project / quota: terraform.tfvars only (not gcloud config).
provider "google" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
  region                = var.region
}

provider "google-beta" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
  region                = var.region
}
