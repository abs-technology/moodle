# Creates the live GCS backend bucket. Apply only via `make init`:
# project_id / location come from terraform/live/terraform.tfvars.
# Auth is ADC. State is local per project: .states/<project_id>/terraform.tfstate

resource "google_project_service" "storage" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-moodle-gke-tfstate"
  location                    = var.location
  project                     = var.project_id
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.storage]
}
