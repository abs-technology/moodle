variable "name" { type = string }
variable "region" { type = string }
variable "nodes_cidr" { type = string }
variable "pods_cidr" { type = string }
variable "services_cidr" { type = string }
variable "gke_node_tag" { type = string }
variable "enable_iap_ssh" {
  type    = bool
  default = false
}
