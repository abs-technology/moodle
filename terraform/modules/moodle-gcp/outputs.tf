output "site_url" {
  value = "https://${local.moodle_domain}"
}

output "public_ip" {
  value = google_compute_address.moodle.address
}

output "instance_name" {
  value = google_compute_instance.moodle.name
}

output "ssh_command" {
  description = "IAP là đường mặc định. Đặt ssh_allowed_cidrs thì dùng break-glass.pem, không cần gcloud còn token."
  value = local.break_glass ? (
    "ssh -i break-glass.pem admin@${google_compute_address.moodle.address}"
    ) : (
    "gcloud compute ssh ${google_compute_instance.moodle.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
  )
}

output "bootstrap_log_command" {
  value = local.break_glass ? (
    "ssh -i break-glass.pem admin@${google_compute_address.moodle.address} 'sudo tail -f /var/log/absi-moodle-bootstrap.log'"
    ) : (
    "gcloud compute ssh ${google_compute_instance.moodle.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap --command 'sudo tail -f /var/log/absi-moodle-bootstrap.log'"
  )
}

output "moodle_admin_user" {
  value = var.moodle_admin_user
}

output "moodle_admin_password" {
  value     = random_password.moodle_admin.result
  sensitive = true
}

output "mariadb_root_password" {
  value     = random_password.mariadb_root.result
  sensitive = true
}
