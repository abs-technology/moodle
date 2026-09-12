variable "project_id" {
  description = "GCP project that will hold the VPC and the VM."
  type        = string
}

variable "credentials" {
  description = "Đường dẫn file JSON key của service account. Để trống thì dùng gcloud application-default credentials."
  type        = string
  default     = ""
}

variable "region" {
  description = "Region for the subnet and the static address."
  type        = string
  default     = "asia-southeast1"
}

variable "zone" {
  description = "Zone for the VM. Must be inside var.region."
  type        = string
  default     = "asia-southeast1-a"
}

variable "name" {
  description = "Prefix for every resource this module creates. Required: IAM roles and key pairs are account-wide, so two deployments sharing a name collide."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name))
    error_message = "name must be lowercase letters, digits and dashes, 3-31 chars, starting with a letter."
  }
}

variable "machine_type" {
  description = "2 vCPU / 4 GB is the smallest size Moodle installs comfortably on."
  type        = string
  default     = "e2-medium"
}

variable "disk_gb" {
  description = "Boot disk size. Moodle code plus moodledata needs ~5 GB to start."
  type        = number
  default     = 30
}

variable "subnet_cidr" {
  description = "CIDR of the single subnet in the new VPC."
  type        = string
  default     = "10.20.0.0/24"
}

variable "moodle_domain" {
  description = "Public hostname. Empty derives moodle.<static-ip>.nip.io, which needs no DNS work."
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
  description = "Mở SSH cho các CIDR này, sinh break-glass.pem và tắt OS Login. Danh sách rỗng thì chỉ vào được qua IAP. Xác thực luôn là key-only."
  type        = list(string)
  default     = []
}

variable "enable_apis" {
  description = "Enable compute.googleapis.com. Turn off if the project already has it and you lack serviceusage rights."
  type        = bool
  default     = true
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
  description = "Snapshot the boot disk every Sunday at 22:00 in var.timezone."
  type        = bool
  default     = true
}

variable "vm_deletion_protection" {
  description = "Block instance delete in the console and API. Set false, apply, then destroy when you really mean to delete the VM."
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
