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

variable "disk_gb" {
  description = "Root volume size. Moodle code plus moodledata needs ~5 GB to start."
  type        = number
  default     = 30
}

variable "vpc_cidr" {
  description = "CIDR of the new VPC."
  type        = string
  default     = "10.21.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR of the single public subnet."
  type        = string
  default     = "10.21.1.0/24"
}

variable "moodle_domain" {
  description = "Public hostname. Empty derives moodle.<elastic-ip>.nip.io, which needs no DNS work."
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
  description = "Mở SSH cho các CIDR này và sinh break-glass.pem. Danh sách rỗng thì chỉ vào được bằng SSM. Xác thực luôn là key-only, Debian AMI tắt sẵn password auth."
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
