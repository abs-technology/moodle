output "connection_name" {
  value = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  value     = google_sql_database_instance.this.private_ip_address
  sensitive = true
}

output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "database_name" {
  value = google_sql_database.moodle.name
}

output "database_user" {
  value = google_sql_user.moodle.name
}
