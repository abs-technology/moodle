# Renders the VM bootstrap script for both clouds from one compose file, so GCP
# and AWS cannot drift apart.
terraform {
  required_version = ">= 1.5"
}

locals {
  acme_caserver = var.acme_staging ? "ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory" : ""

  env_file = <<-EOT
    MOODLE_DOMAIN=${var.moodle_domain}
    TLS_CERTRESOLVER=le
    ACME_EMAIL=${var.acme_email}
    ${local.acme_caserver}
    TRAEFIK_HTTP3=true

    MOODLE_USERNAME=${var.moodle_admin_user}
    MOODLE_PASSWORD=${var.moodle_admin_password}
    MOODLE_EMAIL=${var.acme_email}
    MOODLE_SITE_NAME=${var.moodle_site_name}

    MARIADB_ROOT_PASSWORD=${var.mariadb_root_password}
    MARIADB_USER=abs_moodle_user
    MARIADB_PASSWORD=${var.mariadb_password}
    MARIADB_DATABASE=abs_moodle_db
  EOT
}
