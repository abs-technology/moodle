output "dashboard_id" {
  value = reverse(split("/", google_monitoring_dashboard.moodle.id))[0]
}
