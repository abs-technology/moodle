output "network_id" {
  value = google_compute_network.this.id
}

output "network_name" {
  value = google_compute_network.this.name
}

output "network_self_link" {
  value = google_compute_network.this.self_link
}

output "subnet_id" {
  value = google_compute_subnetwork.nodes.id
}

output "subnet_name" {
  value = google_compute_subnetwork.nodes.name
}

output "pods_range_name" {
  value = "pods"
}

output "services_range_name" {
  value = "services"
}

output "sql_peering_ready" {
  description = "PSA connection + exported routes. Cloud SQL must wait for both."
  value       = "${google_service_networking_connection.sql.id}|${google_compute_network_peering_routes_config.sql.id}"
}
