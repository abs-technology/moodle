output "site_url" { value = module.moodle.site_url }
output "public_ip" { value = module.moodle.public_ip }
output "instance_name" { value = module.moodle.instance_name }
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
