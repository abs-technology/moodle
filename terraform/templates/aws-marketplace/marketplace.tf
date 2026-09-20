# Extra root-module variables (not in moodle-aws). Copied next to variables.tf.
# Launch permission for 679593333241 is added with the AMI. AccessARN is
# abs-ami-marketplace-role (created here or looked up if it already exists).

variable "create_ami" {
  description = "Scrub authorized_keys, stop the VM, register an unencrypted IMDSv2 AMI, and share it with 679593333241. Set true only after /readyz is 200."
  type        = bool
  default     = false
}

variable "ami_name" {
  description = "Registered AMI name. Empty uses <name>-marketplace."
  type        = string
  default     = ""
}

variable "marketplace_role_name" {
  description = "IAM role name pasted as AccessARN in Seller Portal (full ARN is output)."
  type        = string
  default     = "abs-ami-marketplace-role"
}

variable "manage_marketplace_role" {
  description = "true creates the role. false looks up an existing role of marketplace_role_name (this seller account already has it)."
  type        = bool
  default     = false
}

data "aws_ebs_encryption_by_default" "marketplace" {}

data "aws_iam_role" "marketplace" {
  count = var.manage_marketplace_role ? 0 : 1
  name  = var.marketplace_role_name
}

data "aws_iam_policy_document" "marketplace_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["assets.marketplace.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "marketplace" {
  count              = var.manage_marketplace_role ? 1 : 0
  name               = var.marketplace_role_name
  description        = "AWS Marketplace AMI ingestion (AccessARN)"
  assume_role_policy = data.aws_iam_policy_document.marketplace_assume.json
}

resource "aws_iam_role_policy_attachment" "marketplace" {
  count      = var.manage_marketplace_role ? 1 : 0
  role       = aws_iam_role.marketplace[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSMarketplaceAmiIngestion"
}

locals {
  ami_name = var.ami_name != "" ? var.ami_name : "${var.name}-marketplace"
  # AWS Marketplace AMI ingestion account (public, documented by AWS).
  marketplace_ingestion_account = "679593333241"
  marketplace_role_arn = (
    var.manage_marketplace_role
    ? aws_iam_role.marketplace[0].arn
    : data.aws_iam_role.marketplace[0].arn
  )
}

# Account-level default encryption would silently encrypt the root volume and
# the snapshot — the same Marketplace rejection as ami-0aa08c23f78ebb719.
resource "terraform_data" "marketplace_unencrypted" {
  lifecycle {
    precondition {
      condition     = !data.aws_ebs_encryption_by_default.marketplace.enabled
      error_message = "EBS default encryption is on in this region. Marketplace AMI products cannot use encrypted snapshots. Disable it (EC2 → Data protection → EBS encryption) in us-east-1, then apply."
    }
  }
}

# SSM as root — do this while the instance is running, then stop (no reboot,
# or cloud-init could write the builder key pair back into authorized_keys).
resource "terraform_data" "marketplace_scrub_ssh" {
  count = var.create_ami ? 1 : 0

  depends_on = [
    terraform_data.marketplace_unencrypted,
    module.moodle,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = merge(
      {
        AWS_REGION         = var.region
        AWS_DEFAULT_REGION = var.region
        AWS_PAGER          = ""
        ABSI_INSTANCE_ID   = module.moodle.instance_id
        ABSI_SCRUB_SCRIPT  = "${path.module}/scrub-ssh.sh"
      },
      var.access_key != "" && var.secret_key != "" ? {
        AWS_ACCESS_KEY_ID     = var.access_key
        AWS_SECRET_ACCESS_KEY = var.secret_key
      } : {},
      var.profile != "" ? { AWS_PROFILE = var.profile } : {},
    )
    command = "python3 ${path.module}/scrub-ssh-remote.py"
  }
}

resource "aws_ec2_instance_state" "marketplace_ami" {
  count       = var.create_ami ? 1 : 0
  instance_id = module.moodle.instance_id
  state       = "stopped"

  depends_on = [terraform_data.marketplace_scrub_ssh]
}

resource "aws_ebs_snapshot" "marketplace" {
  count       = var.create_ami ? 1 : 0
  volume_id   = module.moodle.root_volume_id
  description = "Unencrypted Marketplace snapshot for ${var.name}"

  depends_on = [aws_ec2_instance_state.marketplace_ami]

  tags = {
    Name    = local.ami_name
    Purpose = "aws-marketplace"
  }
}

# RegisterImage (not CreateImage) so we can set imds_support = v2.0.
# https://docs.aws.amazon.com/marketplace/latest/userguide/best-practices-for-building-your-amis.html
resource "aws_ami" "marketplace" {
  count               = var.create_ami ? 1 : 0
  name                = local.ami_name
  description         = "ABS Technology Moodle Marketplace AMI (${var.os})"
  virtualization_type = "hvm"
  architecture        = "x86_64"
  root_device_name    = "/dev/xvda"
  ena_support         = true
  sriov_net_support   = "simple"
  imds_support        = "v2.0"

  ebs_block_device {
    device_name           = "/dev/xvda"
    snapshot_id           = aws_ebs_snapshot.marketplace[0].id
    volume_type           = "gp3"
    volume_size           = var.disk_gb
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name    = local.ami_name
    Purpose = "aws-marketplace"
  }
}

resource "aws_ami_launch_permission" "marketplace" {
  count      = var.create_ami ? 1 : 0
  image_id   = aws_ami.marketplace[0].id
  account_id = local.marketplace_ingestion_account
}

resource "aws_snapshot_create_volume_permission" "marketplace" {
  count       = var.create_ami ? 1 : 0
  snapshot_id = aws_ebs_snapshot.marketplace[0].id
  account_id  = local.marketplace_ingestion_account
}
