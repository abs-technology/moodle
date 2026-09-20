variable "project_id" { type = string }
variable "name" { type = string }
variable "region" { type = string }
variable "network_self_link" { type = string }
variable "subnet_id" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }
variable "gke_node_tag" { type = string }

variable "master_cidr" {
  type    = string
  default = "172.16.0.32/28"
}

variable "enable_private_endpoint" {
  type    = bool
  default = false
}

variable "master_authorized_cidrs" {
  type = list(object({
    cidr = string
    name = string
  }))
  default = [{
    cidr = "0.0.0.0/0"
    name = "temporary-open"
  }]
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "binary_authorization_mode" {
  type    = string
  default = "DISABLED"
}

variable "authenticator_security_group" {
  type    = string
  default = null
}

variable "database_encryption_key" {
  type    = string
  default = ""
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "node_disk_gb" {
  type    = number
  default = 80
}

variable "node_locations" {
  type        = list(string)
  description = "Zones that receive nodes. Regional control plane stays on var.region."
}

variable "min_nodes" {
  type        = number
  default     = 3
  description = "Total floor across node_locations. Enforced as ceil(min/zones) per zone (3 zones → 1 each)."
}

variable "max_nodes" {
  type        = number
  default     = 12
  description = "Total ceiling across node_locations. Enforced as ceil(max/zones) per zone (3 zones → 4 each)."
}

# Sunday 00:00–08:00 Asia/Ho_Chi_Minh = Saturday 17:00–Sunday 01:00 UTC.
variable "maintenance_start" {
  type    = string
  default = "2026-01-10T17:00:00Z"
}

variable "maintenance_end" {
  type    = string
  default = "2026-01-11T01:00:00Z"
}

variable "maintenance_recurrence" {
  type    = string
  default = "FREQ=WEEKLY;BYDAY=SA"
}
