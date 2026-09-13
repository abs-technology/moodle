# Global external Application Load Balancer (EXTERNAL_MANAGED, not Classic).
# gcp-alb only: ALB → NEG :8080 → Moodle. No Traefik. AWS is modules/moodle-aws/alb.tf.

locals {
  alb              = var.enable_global_alb
  alb_backend_port = 8080
  alb_proxy_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_project_service" "certmanager" {
  count              = var.enable_apis && local.alb ? 1 : 0
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_global_address" "alb" {
  count      = local.alb ? 1 : 0
  name       = "${var.name}-alb"
  ip_version = "IPV4"
  depends_on = [google_project_service.compute]
}

# Egress for apt/docker/Moodle once the VM has no public IP.
resource "google_compute_router" "alb" {
  count   = local.alb ? 1 : 0
  name    = "${var.name}-nat"
  region  = var.region
  network = google_compute_network.moodle.id
}

resource "google_compute_router_nat" "alb" {
  count                              = local.alb ? 1 : 0
  name                               = "${var.name}-nat"
  router                             = google_compute_router.alb[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.moodle.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}

# Default Cloud Armor policy only: allow all, no Adaptive Protection,
# no preconfigured WAF, no bot/threat intel (those bill extra).
resource "google_compute_security_policy" "alb" {
  count = local.alb ? 1 : 0
  name  = "${var.name}-armor"
  type  = "CLOUD_ARMOR"

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default allow"
  }
}

resource "google_compute_health_check" "alb" {
  count               = local.alb ? 1 : 0
  name                = "${var.name}-readyz"
  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = local.alb_backend_port
    request_path = "/readyz"
  }
}

resource "google_compute_network_endpoint_group" "alb" {
  count                 = local.alb ? 1 : 0
  name                  = "${var.name}-neg"
  zone                  = var.zone
  network               = google_compute_network.moodle.id
  subnetwork            = google_compute_subnetwork.moodle.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = local.alb_backend_port
}

resource "google_compute_network_endpoint" "alb" {
  count                  = local.alb ? 1 : 0
  network_endpoint_group = google_compute_network_endpoint_group.alb[0].name
  zone                   = var.zone
  instance               = google_compute_instance.moodle.name
  port                   = local.alb_backend_port
  ip_address             = google_compute_instance.moodle.network_interface[0].network_ip
}

resource "google_compute_backend_service" "alb" {
  count                 = local.alb ? 1 : 0
  name                  = "${var.name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 60
  health_checks         = [google_compute_health_check.alb[0].id]
  security_policy       = google_compute_security_policy.alb[0].id

  log_config {
    enable = false
  }

  backend {
    group                 = google_compute_network_endpoint_group.alb[0].id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  depends_on = [google_compute_network_endpoint.alb]
}

resource "google_compute_url_map" "https" {
  count           = local.alb ? 1 : 0
  name            = "${var.name}-https"
  default_service = google_compute_backend_service.alb[0].id
}

resource "google_compute_url_map" "http_redirect" {
  count = local.alb ? 1 : 0
  name  = "${var.name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_certificate_manager_certificate" "alb" {
  count    = local.alb ? 1 : 0
  name     = "${var.name}-cert"
  location = "global"

  managed {
    domains = [local.moodle_domain]
  }

  depends_on = [google_project_service.certmanager]
}

resource "google_certificate_manager_certificate_map" "alb" {
  count = local.alb ? 1 : 0
  name  = "${var.name}-certmap"
}

resource "google_certificate_manager_certificate_map_entry" "alb" {
  count        = local.alb ? 1 : 0
  name         = "${var.name}-cert-entry"
  map          = google_certificate_manager_certificate_map.alb[0].name
  certificates = [google_certificate_manager_certificate.alb[0].id]
  hostname     = local.moodle_domain
}

resource "google_compute_target_https_proxy" "alb" {
  count           = local.alb ? 1 : 0
  name            = "${var.name}-https"
  url_map         = google_compute_url_map.https[0].id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.alb[0].id}"
  depends_on      = [google_certificate_manager_certificate_map_entry.alb]
}

resource "google_compute_target_http_proxy" "alb" {
  count   = local.alb ? 1 : 0
  name    = "${var.name}-http"
  url_map = google_compute_url_map.http_redirect[0].id
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = local.alb ? 1 : 0
  name                  = "${var.name}-https"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  ip_address            = google_compute_global_address.alb[0].id
  target                = google_compute_target_https_proxy.alb[0].id
}

resource "google_compute_global_forwarding_rule" "http" {
  count                 = local.alb ? 1 : 0
  name                  = "${var.name}-http"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  ip_address            = google_compute_global_address.alb[0].id
  target                = google_compute_target_http_proxy.alb[0].id
}
