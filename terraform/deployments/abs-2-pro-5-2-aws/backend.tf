# Sinh tự động bởi scripts/tf-deployments.sh. Bucket nằm cùng account với hạ tầng
# (759945100716), vì cả hai đều dùng credential trong terraform.tfvars của deployment này.
terraform {
  backend "s3" {
    bucket       = "absi-moodle-tfstate-759945100716"
    key          = "deployments/abs-2-pro-5-2-aws.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
