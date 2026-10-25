terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 8.0"
    }
  }
}

resource "google_service_account" "nodes" {
  account_id   = "${var.name}-gke-nodes"
  display_name = "GKE node SA for ${var.name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  provider = google-beta

  name           = var.name
  location       = var.region
  node_locations = var.node_locations
  project        = var.project_id

  network    = var.network_self_link
  subnetwork = var.subnet_id

  networking_mode   = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gcs_fuse_csi_driver_config {
      enabled = true
    }
    dns_cache_config {
      enabled = true
    }
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
      "STORAGE",
      "HPA",
      "POD",
      "DEPLOYMENT",
    ]
    managed_prometheus {
      enabled = true
    }
  }

  binary_authorization {
    evaluation_mode = var.binary_authorization_mode
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  dynamic "authenticator_groups_config" {
    for_each = var.authenticator_security_group != null && var.authenticator_security_group != "" ? [1] : []
    content {
      security_group = var.authenticator_security_group
    }
  }

  dynamic "database_encryption" {
    for_each = var.database_encryption_key != "" ? [1] : []
    content {
      state    = "ENCRYPTED"
      key_name = var.database_encryption_key
    }
  }

  node_config {
    service_account = google_service_account.nodes.email
    tags            = [var.gke_node_tag]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start
      end_time   = var.maintenance_end
      recurrence = var.maintenance_recurrence
    }
  }

  deletion_protection = var.deletion_protection

  depends_on = [google_project_iam_member.nodes]

  lifecycle {
    ignore_changes = [node_config]
  }
}

locals {
  min_nodes_per_zone = max(1, ceil(var.min_nodes / length(var.node_locations)))
  min_nodes_total    = local.min_nodes_per_zone * length(var.node_locations)
}

resource "google_container_node_pool" "default" {
  provider = google-beta

  name           = "default"
  cluster        = google_container_cluster.this.name
  location       = var.region
  node_locations = var.node_locations
  project        = var.project_id

  # Per-zone min/max (not total_*). total_min does not keep a node in every
  # zone — CA can sit at 1 node if pending pods fail a non-resource predicate
  # (e.g. unbound PVC). min_node_count=1 × 3 zones = 3 nodes regional.
  autoscaling {
    min_node_count  = local.min_nodes_per_zone
    max_node_count  = max(1, ceil(var.max_nodes / length(var.node_locations)))
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    disk_type       = "pd-ssd"
    disk_size_gb    = var.node_disk_gb
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = [var.gke_node_tag]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    gvnic {
      enabled = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      app = var.name
    }
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  depends_on = [google_project_iam_member.nodes]
}

# google_container_node_pool returns after the API write. MIG scale-up is
# async — Helm must not start until each zone has a RUNNING node.
resource "terraform_data" "wait_nodes" {
  depends_on = [google_container_node_pool.default]

  triggers_replace = [
    google_container_node_pool.default.id,
    tostring(local.min_nodes_per_zone),
    tostring(local.min_nodes_total),
    join(",", sort(var.node_locations)),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      PROJECT         = var.project_id
      CLUSTER         = google_container_cluster.this.name
      REGION          = var.region
      POOL            = google_container_node_pool.default.name
      MIN_PER_ZONE    = tostring(local.min_nodes_per_zone)
      MIN_TOTAL       = tostring(local.min_nodes_total)
      TIMEOUT_SECONDS = "900"
    }
    command = "${path.module}/../../../scripts/wait-gke-nodes.sh"
  }
}
