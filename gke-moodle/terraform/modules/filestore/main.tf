terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}

resource "google_filestore_instance" "this" {
  name     = var.name
  location = var.zone
  tier     = var.tier
  protocol = "NFS_V3"
  project  = var.project_id

  file_shares {
    name        = "moodle"
    capacity_gb = var.capacity_gb
    nfs_export_options {
      ip_ranges   = [var.clients_cidr]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network      = var.network_name
    modes        = ["MODE_IPV4"]
    connect_mode = "DIRECT_PEERING"
  }

  deletion_protection_enabled = var.deletion_protection

  kms_key_name = var.cmek_key == "" ? null : var.cmek_key

  labels = {
    app = var.name
  }

  lifecycle {
    precondition {
      condition     = length(var.node_locations) == 0 || contains(var.node_locations, var.zone)
      error_message = "Filestore zone must be listed in node_locations so GKE nodes can mount NFS."
    }
  }
}

# Custom VPC has no default-allow-internal. Kubelet mounts NFS from the node IP.
resource "google_compute_firewall" "nfs" {
  name    = "${var.name}-allow-nfs"
  network = var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["111", "2046", "2049", "2050", "4045"]
  }
  allow {
    protocol = "udp"
    ports    = ["111", "2046", "2049", "4045"]
  }

  source_tags = [var.gke_node_tag]
  direction   = "INGRESS"
}
