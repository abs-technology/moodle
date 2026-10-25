output "site_url" { value = module.moodle.site_url }
output "public_ip" { value = module.moodle.public_ip }
output "instance_id" { value = module.moodle.instance_id }
output "root_volume_id" { value = module.moodle.root_volume_id }
output "ssh_user" { value = module.moodle.ssh_user }
output "ssh_command" { value = module.moodle.ssh_command }
output "bootstrap_log_command" { value = module.moodle.bootstrap_log_command }
output "moodle_admin_user" { value = module.moodle.moodle_admin_user }

output "moodle_admin_password" {
  value     = module.moodle.moodle_admin_password
  sensitive = true
}

output "mariadb_root_password" {
  value     = module.moodle.mariadb_root_password
  sensitive = true
}

output "ami_id" {
  description = "Registered Marketplace AMI. Null until create_ami = true."
  value       = try(aws_ami.marketplace[0].id, null)
}

output "ami_snapshot_id" {
  value = try(aws_ebs_snapshot.marketplace[0].id, null)
}

output "ami_snapshot_encrypted" {
  description = "Must be false. Marketplace rejects encrypted snapshots."
  value       = try(aws_ebs_snapshot.marketplace[0].encrypted, null)
}

output "ami_shared_with" {
  description = "AWS Marketplace ingestion account that has launch permission."
  value       = var.create_ami ? local.marketplace_ingestion_account : null
}

output "marketplace_access_arn" {
  description = "AccessARN for Seller Portal (full IAM role ARN)."
  value       = local.marketplace_role_arn
}

output "marketplace_role_name" {
  value = var.marketplace_role_name
}
