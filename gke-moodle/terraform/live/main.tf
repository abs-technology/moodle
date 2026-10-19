data "google_project" "this" {
  project_id = var.project_id
}

locals {
  gke_node_tag  = "${var.name}-node"
  hostname      = "moodle.${google_compute_global_address.alb.address}.nip.io"
  wwwroot       = "https://${local.hostname}"
  namespace     = "moodle"
  ksa           = "moodle"
  image_prefix  = module.artifact_registry.image_prefix
  use_filestore = var.storage_backend == "filestore"
  cmek_key      = var.enable_cmek ? google_kms_crypto_key.this[0].id : ""
}

check "filestore_zone" {
  assert {
    condition     = !local.use_filestore || contains(var.node_locations, var.zone)
    error_message = "var.zone must be one of var.node_locations (Filestore NFS from GKE nodes)."
  }
}

module "apis" {
  source     = "../modules/apis"
  project_id = var.project_id
}

resource "google_kms_key_ring" "this" {
  count      = var.enable_cmek ? 1 : 0
  name       = "${var.name}-gke"
  location   = var.region
  project    = var.project_id
  depends_on = [module.apis]
}

resource "google_kms_crypto_key" "this" {
  count           = var.enable_cmek ? 1 : 0
  name            = "moodle"
  key_ring        = google_kms_key_ring.this[0].id
  rotation_period = "7776000s"
}

resource "google_kms_crypto_key_iam_member" "cmek" {
  for_each = var.enable_cmek ? {
    gke       = "serviceAccount:service-${data.google_project.this.number}@container-engine-robot.iam.gserviceaccount.com"
    sql       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    filestore = "serviceAccount:service-${data.google_project.this.number}@cloud-filer.iam.gserviceaccount.com"
    artifacts = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
  } : {}

  crypto_key_id = google_kms_crypto_key.this[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}

module "network" {
  source        = "../modules/network"
  name          = var.name
  region        = var.region
  nodes_cidr    = var.nodes_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
  gke_node_tag  = local.gke_node_tag
  depends_on    = [module.apis]
}

module "gke" {
  source = "../modules/gke"

  providers = {
    google      = google
    google-beta = google-beta
  }

  project_id                = var.project_id
  name                      = var.name
  region                    = var.region
  network_self_link         = module.network.network_self_link
  subnet_id                 = module.network.subnet_id
  pods_range_name           = module.network.pods_range_name
  services_range_name       = module.network.services_range_name
  gke_node_tag              = local.gke_node_tag
  master_cidr               = var.master_cidr
  master_authorized_cidrs   = var.master_authorized_cidrs
  machine_type              = var.node_machine_type
  node_locations            = var.node_locations
  min_nodes                 = var.min_nodes
  max_nodes                 = var.max_nodes
  deletion_protection       = var.deletion_protection
  binary_authorization_mode = var.binary_authorization_enforce ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  database_encryption_key   = local.cmek_key

  depends_on = [module.network, google_kms_crypto_key_iam_member.cmek]
}

module "secrets" {
  source     = "../modules/secrets"
  project_id = var.project_id
  name       = var.name
  depends_on = [module.apis]
}

module "cloudsql" {
  source = "../modules/cloudsql"

  project_id             = var.project_id
  name                   = var.name
  region                 = var.region
  network_id             = module.network.network_id
  private_vpc_connection = module.network.sql_peering_ready
  tier                   = var.sql_tier
  disk_gb                = var.sql_disk_gb
  max_connections        = var.sql_max_connections
  database_password      = module.secrets.db_password
  deletion_protection    = var.deletion_protection
  cmek_key               = local.cmek_key

  depends_on = [module.network, google_kms_crypto_key_iam_member.cmek]
}

module "filestore" {
  count  = local.use_filestore ? 1 : 0
  source = "../modules/filestore"

  project_id          = var.project_id
  name                = "${var.name}-fs"
  zone                = var.zone
  network_name        = module.network.network_name
  gke_node_tag        = local.gke_node_tag
  clients_cidr        = var.nodes_cidr
  tier                = var.filestore_tier
  capacity_gb         = var.filestore_gb
  node_locations      = var.node_locations
  deletion_protection = var.deletion_protection
  cmek_key            = local.cmek_key

  depends_on = [module.network, google_kms_crypto_key_iam_member.cmek]
}

module "artifact_registry" {
  source     = "../modules/artifact-registry"
  project_id = var.project_id
  location   = var.region
  cmek_key   = local.cmek_key
  depends_on = [module.apis, google_kms_crypto_key_iam_member.cmek]
}

module "binary_auth" {
  source       = "../modules/binary-auth"
  project_id   = var.project_id
  image_prefix = local.image_prefix
  enforce      = var.binary_authorization_enforce
  depends_on   = [module.apis]
}

module "armor" {
  source     = "../modules/armor"
  project_id = var.project_id
  name       = var.name
  depends_on = [module.apis]
}

resource "google_compute_global_address" "alb" {
  name         = "${var.name}-alb"
  project      = var.project_id
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
  depends_on   = [module.apis]
}

resource "google_certificate_manager_certificate" "alb" {
  name     = "${var.name}-cert"
  project  = var.project_id
  location = "global"
  managed {
    domains = [local.hostname]
  }
  depends_on = [module.apis]
}

resource "google_certificate_manager_certificate_map" "alb" {
  name       = "${var.name}-certmap"
  project    = var.project_id
  depends_on = [module.apis]
}

resource "google_certificate_manager_certificate_map_entry" "alb" {
  name         = "${var.name}-cert-entry"
  project      = var.project_id
  map          = google_certificate_manager_certificate_map.alb.name
  certificates = [google_certificate_manager_certificate.alb.id]
  hostname     = local.hostname
}

resource "google_service_account" "moodle" {
  account_id   = "${var.name}-ksa"
  display_name = "Moodle Workload Identity"
  project      = var.project_id
  depends_on   = [module.apis]
}

resource "google_project_iam_member" "moodle_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.moodle.email}"
}

resource "google_project_iam_member" "moodle_metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.moodle.email}"
}

# Binding can exist before the KSA. Annotate ServiceAccount moodle/moodle when you deploy.
resource "google_service_account_iam_member" "moodle_wi" {
  service_account_id = google_service_account.moodle.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.namespace}/${local.ksa}]"
}

module "monitoring" {
  source             = "../modules/monitoring"
  project_id         = var.project_id
  name               = var.name
  sql_instance_name  = module.cloudsql.instance_name
  notification_email = var.notification_email
  depends_on         = [module.cloudsql]
}
