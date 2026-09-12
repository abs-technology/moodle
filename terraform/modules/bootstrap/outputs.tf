output "script" {
  description = "Cloud-agnostic bash, usable as GCP startup-script or AWS user_data."
  sensitive   = true

  value = templatefile("${path.module}/../../bootstrap.sh.tftpl", {
    compose_file    = file("${path.module}/../../../examples/${var.compose_relpath}")
    traefik_compose = var.compose_relpath == "ip/docker-compose.yml" ? file("${path.module}/../../../examples/traefik/docker-compose.yml") : ""
    tls_example     = file("${path.module}/../../../examples/traefik/dynamic/tls.yml.example")
    change_domain   = file("${path.module}/../../../examples/traefik/change-domain.sh")
    env_file        = local.env_file
    readme          = local.readme
    extra_bootstrap = var.extra_bootstrap
    timezone        = var.timezone
  })
}
