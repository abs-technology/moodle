variable "project_id" {
  type        = string
  description = "GCP project that owns this stack (not reused from terraform/ VM modules)."
}

variable "name" {
  type    = string
  default = "moodle"
}

variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "zone" {
  type        = string
  default     = "asia-southeast1-b"
  description = "Filestore zone. Must be in node_locations. If create fails with 'not enough resources', pick another zone."
}

variable "nodes_cidr" {
  type    = string
  default = "10.20.0.0/20"
}

variable "pods_cidr" {
  type    = string
  default = "10.84.0.0/14"
}

variable "services_cidr" {
  type    = string
  default = "10.88.0.0/20"
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.32/28"
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

variable "node_locations" {
  type        = list(string)
  default     = ["asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c"]
  description = "GKE node zones (regional cluster). Keep in sync with var.region."
}

variable "node_machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "min_nodes" {
  type        = number
  default     = 3
  description = "Total floor across node_locations. Node pool uses per-zone min = ceil(min_nodes / zones)."
}

variable "max_nodes" {
  type    = number
  default = 12
}

variable "sql_tier" {
  type        = string
  default     = "db-perf-optimized-N-8"
  description = "Enterprise Plus 8 vCPU / 64 GiB."
}

variable "sql_disk_gb" {
  type    = number
  default = 100
}

variable "sql_max_connections" {
  type        = number
  default     = 1000
  description = "php-fpm is 5 workers/pod. Keep maxReplicas × 5 well under this."
}

variable "storage_backend" {
  type        = string
  default     = "filestore"
  description = "filestore = NFS RWX (min ~1 TiB, multi-replica). pd = GCE disk PVC (RWO, 1 replica)."
  validation {
    condition     = contains(["pd", "filestore"], var.storage_backend)
    error_message = "storage_backend must be pd or filestore."
  }
}

variable "pd_size_gb" {
  type        = number
  default     = 50
  description = "GCE Persistent Disk size when storage_backend = pd. Grow online later."
}

variable "pd_storage_class" {
  type        = string
  default     = "standard-rwo"
  description = "GKE class: standard-rwo (balanced) or premium-rwo (SSD)."
}

variable "filestore_tier" {
  type    = string
  default = "ZONAL"
}

variable "filestore_gb" {
  type    = number
  default = 1024
}

variable "moodle_image_repository" {
  type        = string
  default     = "abstechnology/moodle-standard"
  description = "After mirroring, set to <region>-docker.pkg.dev/<project>/moodle/moodle-standard"
}

variable "moodle_image_tag" {
  type    = string
  default = "5.2.2-r5"
}

variable "moodle_admin_email" {
  type    = string
  default = "henry@absi.edu.vn"
}

variable "notification_email" {
  type    = string
  default = ""
}

variable "binary_authorization_enforce" {
  type        = bool
  default     = false
  description = "true after the image is in Artifact Registry. Blocks Docker Hub pulls."
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "enable_cmek" {
  type    = bool
  default = false
}
