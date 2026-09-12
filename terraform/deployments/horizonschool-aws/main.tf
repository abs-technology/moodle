# One customer deployment on AWS. Copied by `make tf-new`; horizonschool-aws is substituted
# with the directory name.
terraform {
  required_version = ">= 1.10"

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

  # State lives centrally, one object per deployment, so losing this working copy
  # never costs the ability to manage or destroy a customer's stack.
  # use_lockfile needs Terraform 1.10+ and replaces the old DynamoDB table.
  # Backend nằm ở backend.tf.
}

# Credentials come from this deployment's terraform.tfvars, so each customer can
# sit in its own AWS account.
provider "aws" {
  region = var.region

  access_key = var.access_key != "" ? var.access_key : null
  secret_key = var.secret_key != "" ? var.secret_key : null
  profile    = var.profile != "" ? var.profile : null

  default_tags {
    tags = {
      Project    = "absi-tech-moodle"
      ManagedBy  = "terraform"
      Deployment = "horizonschool-aws"
    }
  }
}

module "moodle" {
  source = "../../modules/moodle-aws"

  name                   = var.name
  region                 = var.region
  access_key             = var.access_key
  secret_key             = var.secret_key
  profile                = var.profile
  availability_zone      = var.availability_zone
  instance_type          = var.instance_type
  disk_gb                = var.disk_gb
  vpc_cidr               = var.vpc_cidr
  subnet_cidr            = var.subnet_cidr
  moodle_domain          = var.moodle_domain
  acme_email             = var.acme_email
  acme_staging           = var.acme_staging
  moodle_admin_user      = var.moodle_admin_user
  ssh_allowed_cidrs      = var.ssh_allowed_cidrs
  timezone               = var.timezone
  snapshot_weekly        = var.snapshot_weekly
  snapshot_retain_weeks  = var.snapshot_retain_weeks
  vm_deletion_protection = var.vm_deletion_protection
}
