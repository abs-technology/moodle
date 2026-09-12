# Sinh tự động bởi scripts/tf-deployments.sh. Bucket nằm cùng account với hạ tầng
# (393080455815), vì cả hai đều dùng credential trong terraform.tfvars của deployment này.
terraform {
  backend "s3" {
    bucket       = "absi-moodle-tfstate-393080455815"
    key          = "deployments/abs-2-pro-5-2-aws.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
