terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}

resource "google_compute_network" "this" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "nodes" {
  name                     = "${var.name}-nodes"
  ip_cidr_range            = var.nodes_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.nodes.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "sql_peering" {
  name          = "${var.name}-sql-peering"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "sql" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_peering.name]
  # Cloud SQL keeps the producer-side PSA allocation after instance delete
  # (restore window). deleteConnection then fails and blocks VPC teardown.
  # REMOVE_PEERING drops the consumer peering so the network can go.
  deletion_policy = "REMOVE_PEERING"
}

# Default Service Networking peering does not export custom/pod routes.
# Without this, Cloud SQL may not reply to GKE pod IPs (10.84.0.0/14).
resource "google_compute_network_peering_routes_config" "sql" {
  peering              = google_service_networking_connection.sql.peering
  network              = google_compute_network.this.name
  import_custom_routes = true
  export_custom_routes = true
}

# GCE health checks to NEG / nodes.
resource "google_compute_firewall" "lb_health" {
  name    = "${var.name}-allow-lb-health"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]
  target_tags = [var.gke_node_tag]
}

resource "google_compute_firewall" "iap_ssh" {
  count   = var.enable_iap_ssh ? 1 : 0
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.gke_node_tag]
}
