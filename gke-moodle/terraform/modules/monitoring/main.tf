terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  count        = var.notification_email == "" ? 0 : 1
  display_name = "${var.name} email"
  type         = "email"
  project      = var.project_id
  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_alert_policy" "sql_cpu" {
  display_name = "${var.name} Cloud SQL CPU"
  project      = var.project_id
  combiner     = "OR"
  conditions {
    display_name = "SQL CPU > 80%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${var.sql_instance_name}\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  notification_channels = [for c in google_monitoring_notification_channel.email : c.id]
}

resource "google_monitoring_dashboard" "moodle" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "${var.name} infra"
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "Cloud SQL CPU"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\""
                }
              }
            }]
          }
        },
        {
          title = "Cloud SQL connections"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"cloudsql.googleapis.com/database/network/connections\" resource.type=\"cloudsql_database\""
                }
              }
            }]
          }
        }
      ]
    }
  })
}
