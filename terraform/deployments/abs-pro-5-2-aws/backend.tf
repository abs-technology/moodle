# Sinh tự động bởi scripts/tf-deployments.sh. Một bucket cho đúng deployment này,
# cùng account (759945100716) và cùng region với VM.
terraform {
  backend "s3" {
    bucket       = "absi-moodle-tfstate-759945100716-abs-pro-5-2-aws"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
