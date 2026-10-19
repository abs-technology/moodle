variable "project_id" { type = string }
variable "name" { type = string }
variable "region" { type = string }
variable "network_id" { type = string }

variable "private_vpc_connection" {
  type        = string
  description = "Service Networking connection id. Forces SQL to wait for PSA."
}

variable "tier" {
  type    = string
  default = "db-perf-optimized-N-8"
}

variable "disk_gb" {
  type    = number
  default = 100
}

variable "database_name" {
  type    = string
  default = "moodle"
}

variable "database_user" {
  type    = string
  default = "moodle"
}

variable "database_password" {
  type      = string
  sensitive = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "cmek_key" {
  type    = string
  default = ""
}

variable "max_connections" {
  type        = number
  default     = 1000
  description = "php-fpm is 5 workers/pod. Keep maxReplicas × 5 well under this."
}
