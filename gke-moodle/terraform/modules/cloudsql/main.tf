terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_sql_database_instance" "this" {
  name                = "${var.name}-${random_id.suffix.hex}"
  database_version    = "MYSQL_8_4"
  region              = var.region
  project             = var.project_id
  deletion_protection = var.deletion_protection

  settings {
    tier                  = var.tier
    edition               = "ENTERPRISE_PLUS"
    availability_type     = "REGIONAL"
    disk_type             = "PD_SSD"
    disk_size             = var.disk_gb
    disk_autoresize       = true
    disk_autoresize_limit = 0

    data_cache_config {
      data_cache_enabled = true
    }

    backup_configuration {
      enabled    = true
      start_time = "17:00"
      # MySQL PITR is binary_log_enabled (point_in_time_recovery_enabled is Postgres/SQL Server only).
      binary_log_enabled             = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 14
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      ssl_mode                                      = "ENCRYPTED_ONLY"
      enable_private_path_for_google_cloud_services = true
    }

    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    database_flags {
      name  = "character_set_server"
      value = "utf8mb4"
    }
    database_flags {
      name  = "collation_server"
      value = "utf8mb4_unicode_ci"
    }
    database_flags {
      name  = "slow_query_log"
      value = "on"
    }
    database_flags {
      name  = "log_output"
      value = "FILE"
    }
    database_flags {
      name  = "max_connections"
      value = tostring(var.max_connections)
    }

    maintenance_window {
      day          = 7
      hour         = 17
      update_track = "stable"
    }

    user_labels = {
      app     = var.name
      edition = "enterprise-plus"
    }
  }

  encryption_key_name = var.cmek_key == "" ? null : var.cmek_key

  lifecycle {
    precondition {
      condition     = length(var.private_vpc_connection) > 0
      error_message = "Cloud SQL needs Service Networking (pass module.network.sql_peering_ready)."
    }
  }
}

resource "google_sql_database" "moodle" {
  name      = var.database_name
  instance  = google_sql_database_instance.this.name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "moodle" {
  name     = var.database_user
  instance = google_sql_database_instance.this.name
  host     = "%"
  password = var.database_password
}
