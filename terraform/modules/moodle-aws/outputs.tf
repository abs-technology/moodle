output "site_url" {
  value = var.enable_direct_ip ? "http://${aws_eip.moodle.public_ip}" : "https://${local.moodle_domain}"
}

output "public_ip" {
  value = aws_eip.moodle.public_ip
}

output "instance_id" {
  value = aws_instance.moodle.id
}

output "ssh_command" {
  description = "SSM là đường chính. Nếu ssh_allowed_cidr được đặt thì có thêm SSH bằng break-glass.pem."
  value = local.break_glass ? (
    "ssh -i break-glass.pem admin@${aws_eip.moodle.public_ip}"
    ) : (
    "aws ssm start-session --region ${var.region} --target ${aws_instance.moodle.id}"
  )
}

output "bootstrap_log_command" {
  value = local.break_glass ? (
    "ssh -i break-glass.pem admin@${aws_eip.moodle.public_ip} sudo tail -f /var/log/absi-moodle-bootstrap.log"
    ) : (
    "aws ssm start-session --region ${var.region} --target ${aws_instance.moodle.id} --document-name AWS-StartInteractiveCommand --parameters command='sudo tail -f /var/log/absi-moodle-bootstrap.log'"
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
