# Sinh tự động bởi scripts/tf-deployments.sh, trong account 393080455815 — cùng account với
# hạ tầng, vì credential lấy từ terraform.tfvars của chính deployment này.
terraform {
  backend "s3" {
    bucket       = "absi-moodle-tfstate-393080455815"
    key          = "deployments/horizonschool-aws.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
