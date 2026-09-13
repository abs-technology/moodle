output "site_url" {
  value = var.enable_direct_ip ? "http://${local.public_ipv4}" : "https://${local.moodle_domain}"
}

output "public_ip" {
  description = "VM Elastic IP, or the first Global Accelerator anycast IP when enable_global_alb is set."
  value       = local.public_ipv4
}

output "anycast_ips" {
  description = "Both Global Accelerator anycast IPv4 addresses. Empty on Traefik / IP-direct."
  value       = try(aws_globalaccelerator_accelerator.alb[0].ip_sets[0].ip_addresses, [])
}

output "instance_id" {
  value = aws_instance.moodle.id
}

output "ssh_command" {
  description = "SSM is the path when the VM has no public IP (aws-alb) or when ssh_allowed_cidrs is empty."
  value = local.alb || !local.break_glass ? (
    "aws ssm start-session --region ${var.region} --target ${aws_instance.moodle.id}"
    ) : (
    "ssh -i break-glass.pem admin@${aws_eip.moodle[0].public_ip}"
  )
}

output "bootstrap_log_command" {
  value = local.alb || !local.break_glass ? (
    "aws ssm start-session --region ${var.region} --target ${aws_instance.moodle.id} --document-name AWS-StartInteractiveCommand --parameters command='sudo tail -f /var/log/absi-moodle-bootstrap.log'"
    ) : (
    "ssh -i break-glass.pem admin@${aws_eip.moodle[0].public_ip} sudo tail -f /var/log/absi-moodle-bootstrap.log"
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
