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
  description = "Prefix for every resource this module creates."
  type        = string
  default     = "absi-moodle"
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
