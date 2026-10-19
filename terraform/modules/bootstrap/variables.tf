variable "moodle_domain" {
  type = string
}

variable "acme_email" {
  type = string
}

variable "tls_certresolver" {
  description = "le asks Let's Encrypt; empty serves certs/cert.pem through dynamic/tls.yml."
  type        = string
  default     = "le"

  validation {
    condition     = contains(["le", ""], var.tls_certresolver)
    error_message = "tls_certresolver must be \"le\" or an empty string."
  }
}

variable "compose_relpath" {
  description = "Path under examples/. traefik, alb, or ip compose file."
  type        = string
  default     = "traefik/docker-compose.yml"

  validation {
    condition = contains([
      "traefik/docker-compose.yml",
      "alb/docker-compose.yml",
      "ip/docker-compose.yml",
    ], var.compose_relpath)
    error_message = "compose_relpath must be traefik/, alb/, or ip/ docker-compose.yml."
  }
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

variable "compose_up_extra" {
  description = "Extra docker compose arguments before `up -d` (e.g. --profile aws-le)."
  type        = string
  default     = ""
}

variable "issue_acm_cert" {
  description = "Contents of issue-acm-cert.sh. Empty skips installing it."
  type        = string
  default     = ""
}

variable "timezone" {
  description = "IANA timezone written by timedatectl on first boot (and every GCP boot)."
  type        = string
  default     = "Asia/Ho_Chi_Minh"
}
