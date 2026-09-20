output "name" {
  value = google_container_cluster.this.name
}

output "endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "location" {
  value = google_container_cluster.this.location
}

output "node_service_account" {
  value = google_service_account.nodes.email
}

output "nodes_ready" {
  description = "ID of the waiter. Depend on this — not only module.gke — so Helm waits for RUNNING nodes after a pool update."
  value       = terraform_data.wait_nodes.id
}

output "min_nodes_total" {
  value = local.min_nodes_total
}
