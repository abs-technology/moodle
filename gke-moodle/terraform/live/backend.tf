# Bucket name is not hardcoded. `make init` reads project_id from this
# directory's terraform.tfvars, creates gs://<project_id>-moodle-gke-tfstate,
# then passes -backend-config=bucket=...
terraform {
  backend "gcs" {
    prefix = "gke-moodle/live"
  }
}
