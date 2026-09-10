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
  description = "Prefix for every resource this module creates."
  type        = string
  default     = "absi-moodle"
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

variable "enable_apis" {
  description = "Enable compute.googleapis.com. Turn off if the project already has it and you lack serviceusage rights."
  type        = bool
  default     = true
}
