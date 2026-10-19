# Sinh tự động bởi scripts/tf-deployments.sh. Một bucket cho đúng deployment này,
# trong project abs-techcompany-public-2025. Tên: tf_state_bucket / TF_STATE_BUCKET / absi-moodle-tfstate-<name>.
terraform {
  backend "gcs" {
    bucket = "absi-moodle-tfstate-abs-2-pro-5-2-gcp"
    prefix = "deployments/abs-2-pro-5-2-gcp"
  }
}
