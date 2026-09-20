output "hostname" {
  value = local.hostname
}

output "site_url" {
  value = local.wwwroot
}

output "global_ip" {
  value = google_compute_global_address.alb.address
}

output "gke_cluster" {
  value = module.gke.name
}

output "gke_location" {
  value = module.gke.location
}

output "connect" {
  value = "gcloud container clusters get-credentials ${module.gke.name} --region ${module.gke.location} --project ${var.project_id}"
}

output "cloudsql_connection_name" {
  value = module.cloudsql.connection_name
}

output "cloudsql_database" {
  value = module.cloudsql.database_name
}

output "cloudsql_user" {
  value = module.cloudsql.database_user
}

output "cloudsql_private_ip" {
  value     = module.cloudsql.private_ip
  sensitive = true
}

output "db_password_secret" {
  value = module.secrets.db_secret_id
}

output "admin_password_secret" {
  value = module.secrets.admin_secret_id
}

output "moodle_admin_user" {
  value = "absi_admin"
}

output "moodle_admin_password" {
  value     = module.secrets.admin_password
  sensitive = true
}

output "moodle_db_password" {
  value     = module.secrets.db_password
  sensitive = true
}

output "moodle_gsa_email" {
  value = google_service_account.moodle.email
}

output "armor_policy" {
  value = module.armor.policy_name
}

output "cert_map" {
  value = google_certificate_manager_certificate_map.alb.name
}

output "named_address" {
  value = google_compute_global_address.alb.name
}

output "artifact_registry_prefix" {
  value = module.artifact_registry.image_prefix
}

output "filestore" {
  value = local.use_filestore ? {
    ip          = module.filestore[0].ip
    nfs_path    = module.filestore[0].nfs_path
    share       = module.filestore[0].share_name
    capacity_gb = module.filestore[0].capacity_gb
    } : {
    ip          = ""
    nfs_path    = ""
    share       = ""
    capacity_gb = 0
  }
}

# Non-secret Helm overlay. Passwords stay in Secret Manager / kubectl secret.
output "helm_values" {
  value = {
    image = {
      repository = var.moodle_image_repository
      tag        = var.moodle_image_tag
    }
    serviceAccount = {
      name = local.ksa
      annotations = {
        "iam.gke.io/gcp-service-account" = google_service_account.moodle.email
      }
    }
    cloudSql = {
      enabled                = true
      instanceConnectionName = module.cloudsql.connection_name
    }
    replicaCount = local.use_filestore ? 2 : 1
    podDisruptionBudget = {
      enabled = local.use_filestore
    }
    moodle = {
      wwwroot     = local.wwwroot
      adminEmail  = var.moodle_admin_email
      cluster     = local.use_filestore ? "yes" : "no"
      cronEnabled = local.use_filestore ? "no" : "yes"
      database = {
        name = module.cloudsql.database_name
        user = module.cloudsql.database_user
      }
    }
    cronjob = {
      enabled = local.use_filestore
    }
    persistence = local.use_filestore ? {
      mode          = "filestore"
      storageClass  = "moodle-filestore"
      size          = "${var.filestore_gb}Gi"
      accessMode    = "ReadWriteMany"
      volumeName    = "moodle-moodledata"
      existingClaim = "moodle-data"
      } : {
      mode         = "pd"
      storageClass = var.pd_storage_class
      size         = "${var.pd_size_gb}Gi"
      accessMode   = "ReadWriteOnce"
      volumeName   = ""
    }
    gateway = {
      namedAddress = google_compute_global_address.alb.name
      hostname     = local.hostname
      certMap      = google_certificate_manager_certificate_map.alb.name
    }
    backendPolicy = {
      securityPolicy = module.armor.policy_name
    }
    autoscaling = {
      mode        = "none"
      minReplicas = local.use_filestore ? 2 : 1
      maxReplicas = local.use_filestore ? 20 : 1
      stackdriver = {
        enabled   = false
        projectId = var.project_id
      }
    }
    networkPolicy = {
      extraEgressCidrs = ["${nonsensitive(module.cloudsql.private_ip)}/32"]
      dnsCidrs         = [var.services_cidr, var.pods_cidr]
    }
  }
}

output "observability" {
  value = {
    dashboard      = "https://console.cloud.google.com/monitoring/dashboards/builder/${module.monitoring.dashboard_id}?project=${var.project_id}"
    promql         = "https://console.cloud.google.com/monitoring/metrics-explorer?project=${var.project_id}"
    gke            = "https://console.cloud.google.com/kubernetes/workload/overview?project=${var.project_id}"
    prometheus_api = "https://monitoring.googleapis.com/v1/projects/${var.project_id}/location/global/prometheus"
  }
}
