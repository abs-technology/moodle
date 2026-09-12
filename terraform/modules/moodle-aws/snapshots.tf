# EC2 → Lifecycle Manager. Cron is UTC-only: 22:00 Asia/Ho_Chi_Minh = 15:00 UTC.
locals {
  timezone_utc_offset = {
    "Asia/Ho_Chi_Minh" = 7
  }
  snapshot_hour_local = 22
  snapshot_utc_hour   = (local.snapshot_hour_local - local.timezone_utc_offset[var.timezone] + 24) % 24
  snapshot_dlm_cron   = format("cron(0 %d ? * SUN *)", local.snapshot_utc_hour)
}

data "aws_iam_policy_document" "dlm_assume" {
  count = var.snapshot_weekly ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  count              = var.snapshot_weekly ? 1 : 0
  name               = "${var.name}-dlm"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume[0].json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  count      = var.snapshot_weekly ? 1 : 0
  role       = aws_iam_role.dlm[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "weekly" {
  count              = var.snapshot_weekly ? 1 : 0
  description        = "Weekly Sunday 2200 ICT snapshot of ${var.name}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      absi-snapshot = var.name
    }

    schedule {
      name      = "sunday-22-ict"
      copy_tags = true

      create_rule {
        cron_expression = local.snapshot_dlm_cron
      }

      retain_rule {
        count = var.snapshot_retain_weeks
      }
    }
  }

  depends_on = [aws_iam_role_policy_attachment.dlm]
}
