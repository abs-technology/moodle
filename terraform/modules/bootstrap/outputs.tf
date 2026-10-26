output "script" {
  description = "Cloud-agnostic bash, usable as GCP startup-script or AWS user_data."
  sensitive   = true

  value = templatefile("${path.module}/../../bootstrap.sh.tftpl", {
    compose_file     = file("${path.module}/../../../examples/${var.compose_relpath}")
    traefik_compose  = var.compose_relpath == "ip/docker-compose.yml" ? file("${path.module}/../../../examples/traefik/docker-compose.yml") : ""
    ip_compose       = file("${path.module}/../../../examples/ip/docker-compose.yml")
    tls_example      = file("${path.module}/../../../examples/traefik/dynamic/tls.yml.example")
    change_domain    = file("${path.module}/../../../examples/traefik/change-domain.sh")
    env_file         = local.env_file
    readme           = local.readme
    extra_bootstrap  = var.extra_bootstrap
    timezone         = var.timezone
    compose_up_extra = var.compose_up_extra
    issue_acm_cert       = var.issue_acm_cert
    install_marketplace  = var.install_marketplace
    mp_install       = fileexists("${path.module}/../../../script_marketplace/install.sh") ? file("${path.module}/../../../script_marketplace/install.sh") : ""
    mp_configure     = fileexists("${path.module}/../../../script_marketplace/01-configure-moodle.sh") ? file("${path.module}/../../../script_marketplace/01-configure-moodle.sh") : ""
    mp_c2d_utils     = fileexists("${path.module}/../../../script_marketplace/lib/c2d-utils") ? file("${path.module}/../../../script_marketplace/lib/c2d-utils") : ""
    mp_admin         = fileexists("${path.module}/../../../script_marketplace/lib/marketplace-admin.sh") ? file("${path.module}/../../../script_marketplace/lib/marketplace-admin.sh") : ""
    mp_startup       = fileexists("${path.module}/../../../script_marketplace/lib/startup-script.sh") ? file("${path.module}/../../../script_marketplace/lib/startup-script.sh") : ""
    mp_installer     = fileexists("${path.module}/../../../script_marketplace/lib/install-marketplace.sh") ? file("${path.module}/../../../script_marketplace/lib/install-marketplace.sh") : ""
  })
}
