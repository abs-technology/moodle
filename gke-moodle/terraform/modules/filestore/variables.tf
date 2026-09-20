variable "project_id" { type = string }
variable "name" { type = string }
variable "zone" { type = string }
variable "network_name" { type = string }
variable "gke_node_tag" { type = string }
variable "clients_cidr" {
  type        = string
  description = "Node subnet CIDR allowed to mount NFS (kubelet uses the node IP)."
}

variable "tier" {
  type    = string
  default = "ZONAL"
}

variable "capacity_gb" {
  type    = number
  default = 1024
}

variable "reserved_ip_range" {
  type    = string
  default = ""
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "cmek_key" {
  type    = string
  default = ""
}

variable "node_locations" {
  type        = list(string)
  default     = []
  description = "GKE node zones. Filestore zone must be one of these so kubelet can mount NFS."
}
