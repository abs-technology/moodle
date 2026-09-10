terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.region

  # Khai báo access_key/secret_key trong terraform.tfvars, hoặc để trống cả ba biến
  # để provider tự đọc AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
  access_key = var.access_key != "" ? var.access_key : null
  secret_key = var.secret_key != "" ? var.secret_key : null
  profile    = var.profile != "" ? var.profile : null

  default_tags {
    tags = {
      Project   = "absi-tech-moodle"
      ManagedBy = "terraform"
    }
  }
}
