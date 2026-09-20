variable "region" {
  description = "Region for the VPC and the VM."
  type        = string
  default     = "ap-southeast-1"
}

variable "access_key" {
  description = "AWS access key ID. Khai báo trong terraform.tfvars (đã gitignore)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "secret_key" {
  description = "AWS secret access key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "profile" {
  description = "Dùng thay cho access_key/secret_key nếu bạn có profile trong ~/.aws/credentials."
  type        = string
  default     = ""
}

variable "name" {
  description = "Prefix for every resource this module creates. Required: IAM roles and key pairs are account-wide, so two deployments sharing a name collide."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name))
    error_message = "name must be lowercase letters, digits and dashes, 3-31 chars, starting with a letter."
  }
}

variable "availability_zone" {
  description = "Để trống thì lấy AZ thường đầu tiên. Đặt tên Local Zone (ap-southeast-1-han-1a) để dựng trong Local Zone."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "2 vCPU / 4 GB là mức nhỏ nhất Moodle cài được. Local Zone chỉ có c7i/m7i/r7i, không có t3."
  type        = string
  default     = "t3.medium"
}

variable "os" {
  description = "Guest OS for a new VM. First boot only: ami is ignore_changes, so changing this later does not replace a live site. debian-13, debian-12, or ubuntu-24.04."
  type        = string
  default     = "debian-13"

  validation {
    condition     = contains(["debian-13", "debian-12", "ubuntu-24.04"], var.os)
    error_message = "os must be debian-13, debian-12, or ubuntu-24.04."
  }
}

variable "disk_gb" {
  description = "Root volume size. Moodle code plus moodledata needs ~5 GB to start."
  type        = number
  default     = 30
}

variable "root_volume_encrypted" {
  description = "Encrypt the root EBS volume. Customer sites stay true. aws-marketplace must be false — Marketplace AMI products reject encrypted snapshots."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR of the new VPC."
  type        = string
  default     = "10.21.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR of the public subnet (Traefik / IP-direct, and the NAT/ALB subnet in AZ A on aws-alb)."
  type        = string
  default     = "10.21.1.0/24"
}

variable "enable_direct_ip" {
  description = "Set by `make apply aws-ip` / `gcp-ip`. Moodle on http://<public-ip> with no Traefik. change-domain.sh on the VM enables Traefik later."
  type        = bool
  default     = false
}

variable "enable_global_alb" {
  description = "Set by `make apply aws-alb`. Global Accelerator (anycast) + ALB in front, Moodle :8080, NAT; VM has no public IP. No Traefik."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate for the ALB HTTPS listener (same region). Empty on first boot: placeholder, then the VM imports Let's Encrypt for moodle.<anycast-ip>.nip.io. Ignored when enable_global_alb is false."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Public hosted zone that already contains var.moodle_domain. When both are set, ACM issues a trusted cert and Terraform writes the DNS validation records. Ignored when acm_certificate_arn is set or enable_global_alb is false."
  type        = string
  default     = ""
}

variable "moodle_domain" {
  description = "Public hostname. Empty derives moodle.<public-or-anycast-ip>.nip.io, which needs no DNS work. Ignored on apply-ip (wwwroot is the public IP)."
  type        = string
  default     = ""
}

variable "acme_email" {
  description = "Let's Encrypt contact. Needs a real public TLD; .test and .local are rejected."
  type        = string
}

variable "acme_staging" {
  description = "Use the Let's Encrypt staging CA: untrusted certificates, no production rate limit."
  type        = bool
  default     = false
}

variable "moodle_admin_user" {
  description = "Moodle administrator account created on first boot."
  type        = string
  default     = "absi_admin"
}

variable "ssh_allowed_cidrs" {
  description = "Mở SSH cho các CIDR này và sinh break-glass.pem. Danh sách rỗng thì chỉ vào được bằng SSM. Xác thực luôn là key-only (Debian admin / Ubuntu ubuntu)."
  type        = list(string)
  default     = []
}

variable "timezone" {
  description = "IANA timezone for the VM clock and the Sunday 22:00 snapshot. Asia/Ho_Chi_Minh is UTC+7 with no DST."
  type        = string
  default     = "Asia/Ho_Chi_Minh"

  validation {
    condition     = contains(["Asia/Ho_Chi_Minh"], var.timezone)
    error_message = "timezone must be Asia/Ho_Chi_Minh (the snapshot UTC conversion is only defined for this zone)."
  }
}

variable "snapshot_weekly" {
  description = "Snapshot the instance every Sunday at 22:00 in var.timezone."
  type        = bool
  default     = true
}

variable "vm_deletion_protection" {
  description = "Block TerminateInstances in the console and API. Set false, apply, then destroy when you really mean to delete the VM."
  type        = bool
  default     = true
}

variable "snapshot_retain_weeks" {
  description = "How many weekly snapshots to keep."
  type        = number
  default     = 24

  validation {
    condition     = var.snapshot_retain_weeks >= 1 && var.snapshot_retain_weeks <= 52
    error_message = "snapshot_retain_weeks must be between 1 and 52."
  }
}

variable "tf_state_bucket" {
  description = "Optional remote-state bucket. scripts/tf-deployments.sh reads this on first plan/apply. Empty = absi-moodle-tfstate-<deployment> (no account id in the name)."
  type        = string
  default     = ""

  validation {
    condition     = var.tf_state_bucket == "" || can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.tf_state_bucket))
    error_message = "tf_state_bucket must be empty or a 3–63 character [a-z0-9-] name."
  }
}
