output "ip" {
  value = google_filestore_instance.this.networks[0].ip_addresses[0]
}

output "share_name" {
  value = "moodle"
}

output "nfs_path" {
  value = "/moodle"
}

output "capacity_gb" {
  value = var.capacity_gb
}
