output "db_password" {
  value     = random_password.db.result
  sensitive = true
}

output "admin_password" {
  value     = random_password.moodle_admin.result
  sensitive = true
}

output "db_secret_id" {
  value = google_secret_manager_secret.db.secret_id
}

output "admin_secret_id" {
  value = google_secret_manager_secret.admin.secret_id
}
