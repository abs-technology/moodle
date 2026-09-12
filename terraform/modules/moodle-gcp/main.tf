resource "google_project_service" "compute" {
  count              = var.enable_apis ? 1 : 0
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "moodle" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "moodle" {
  name          = "${var.name}-subnet"
  region        = var.region
  network       = google_compute_network.moodle.id
  ip_cidr_range = var.subnet_cidr
}

resource "google_compute_firewall" "web" {
  name    = "${var.name}-allow-web"
  network = google_compute_network.moodle.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # HTTP/3 rides UDP 443.
  allow {
    protocol = "udp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]
}

locals {
  break_glass = length(var.ssh_allowed_cidrs) > 0
}

# Khoá sinh tại chỗ, ghi ra break-glass.pem để vào được VM mà không cần gcloud
# còn token hợp lệ.
resource "tls_private_key" "break_glass" {
  count     = local.break_glass ? 1 : 0
  algorithm = "ED25519"
}

resource "local_sensitive_file" "break_glass" {
  count           = local.break_glass ? 1 : 0
  filename        = "${path.root}/break-glass.pem"
  content         = tls_private_key.break_glass[0].private_key_openssh
  file_permission = "0600"
}

resource "google_compute_firewall" "break_glass_ssh" {
  count   = local.break_glass ? 1 : 0
  name    = "${var.name}-allow-ssh"
  network = google_compute_network.moodle.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_allowed_cidrs
  target_tags   = [var.name]
}

# 22 is reachable only from Google's IAP forwarders, never from the internet.
resource "google_compute_firewall" "iap_ssh" {
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.moodle.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.name]
}

resource "google_compute_address" "moodle" {
  name       = "${var.name}-ip"
  region     = var.region
  depends_on = [google_project_service.compute]
}

resource "random_password" "moodle_admin" {
  length      = 24
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Docker Compose interpolates .env values, so $ ` " ' \ # must not appear.
  override_special = "!@%^*-_=+"
}

resource "random_password" "mariadb_root" {
  length           = 28
  override_special = "!@%^*-_=+"
}

resource "random_password" "mariadb_user" {
  length           = 28
  override_special = "!@%^*-_=+"
}

locals {
  moodle_domain = var.moodle_domain != "" ? var.moodle_domain : "moodle.${google_compute_address.moodle.address}.nip.io"
}

module "bootstrap" {
  source = "../bootstrap"

  moodle_domain         = local.moodle_domain
  acme_email            = var.acme_email
  acme_staging          = var.acme_staging
  moodle_site_name      = "ABS Technology Moodle LMS"
  moodle_admin_user     = var.moodle_admin_user
  moodle_admin_password = random_password.moodle_admin.result
  mariadb_root_password = random_password.mariadb_root.result
  mariadb_password      = random_password.mariadb_user.result
  timezone              = var.timezone
}

resource "google_compute_instance" "moodle" {
  name                = var.name
  zone                = var.zone
  machine_type        = var.machine_type
  tags                = [var.name]
  deletion_protection = var.vm_deletion_protection

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = var.disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.moodle.id

    access_config {
      nat_ip = google_compute_address.moodle.address
    }
  }

  # OS Login keeps SSH access on IAM instead of metadata keys, but it also
  # ignores them — a break-glass key only works with OS Login off.
  metadata = merge(
    {
      startup-script = module.bootstrap.script
      enable-oslogin = local.break_glass ? "FALSE" : "TRUE"
    },
    local.break_glass ? {
      ssh-keys = "admin:${trimspace(tls_private_key.break_glass[0].public_key_openssh)} break-glass"
    } : {}
  )

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # The ACME challenge starts seconds after boot and needs port 80 already open.
  depends_on = [google_compute_firewall.web]

  # Bootstrap changes must not silently replace a VM holding live Moodle data.
  lifecycle {
    ignore_changes = [metadata["startup-script"]]
  }
}
