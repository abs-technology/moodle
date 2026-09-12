# Sinh tự động bởi scripts/tf-deployments.sh, trong project abs-techcompany-public-2025 — cùng project
# với hạ tầng, vì project_id lấy từ terraform.tfvars của chính deployment này.
terraform {
  backend "gcs" {
    bucket = "absi-moodle-tfstate-abs-techcompany-public-2025"
    prefix = "deployments/moodle-alb-gcp"
  }
}
