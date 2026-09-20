output "site_url" {
  value = var.enable_direct_ip ? "http://${google_compute_address.moodle.address}" : "https://${local.moodle_domain}"
}

output "public_ip" {
  description = "Regional VM IP, or the global ALB IP when enable_global_alb is set."
  value       = var.enable_global_alb ? google_compute_global_address.alb[0].address : google_compute_address.moodle.address
}

output "instance_name" {
  value = google_compute_instance.moodle.name
}

output "ssh_user" {
  description = "OS login user for break-glass SSH (admin on Debian, ubuntu on Ubuntu)."
  value       = local.os.ssh_user
}

output "iap_ssh_command" {
  description = "SSH through IAP. Required after apply-alb: the VM has no public IP."
  value       = "gcloud compute ssh ${google_compute_instance.moodle.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
}

output "ssh_command" {
  description = "IAP là đường mặc định. Đặt ssh_allowed_cidrs thì dùng break-glass.pem, không cần gcloud còn token. ALB luôn là IAP."
  value = var.enable_global_alb || !local.break_glass ? (
    "gcloud compute ssh ${google_compute_instance.moodle.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap"
    ) : (
    "ssh -i break-glass.pem ${local.os.ssh_user}@${google_compute_address.moodle.address}"
  )
}

output "bootstrap_log_command" {
  value = var.enable_global_alb || !local.break_glass ? (
    "gcloud compute ssh ${google_compute_instance.moodle.name} --zone ${var.zone} --project ${var.project_id} --tunnel-through-iap --command 'sudo tail -f /var/log/absi-moodle-bootstrap.log'"
    ) : (
    "ssh -i break-glass.pem ${local.os.ssh_user}@${google_compute_address.moodle.address} 'sudo tail -f /var/log/absi-moodle-bootstrap.log'"
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
