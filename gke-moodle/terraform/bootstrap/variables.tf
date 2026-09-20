variable "project_id" {
  type        = string
  description = "From terraform/live/terraform.tfvars (make init -var). Do not add a bootstrap tfvars."
}

variable "location" {
  type        = string
  default     = "asia-southeast1"
  description = "Bucket location (same region as the GKE stack)."
}
