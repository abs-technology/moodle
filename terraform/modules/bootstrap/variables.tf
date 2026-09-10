variable "moodle_domain" {
  type = string
}

variable "acme_email" {
  type = string
}

variable "acme_staging" {
  type = bool
}

variable "moodle_site_name" {
  type = string
}

variable "moodle_admin_user" {
  type = string
}

variable "moodle_admin_password" {
  type      = string
  sensitive = true
}

variable "mariadb_root_password" {
  type      = string
  sensitive = true
}

variable "mariadb_password" {
  type      = string
  sensitive = true
}

variable "extra_bootstrap" {
  description = "Shell run before Docker is installed. AWS uses it for the SSM agent."
  type        = string
  default     = ""
}
