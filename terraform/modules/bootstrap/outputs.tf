output "script" {
  description = "Cloud-agnostic bash, usable as GCP startup-script or AWS user_data."
  sensitive   = true

  value = templatefile("${path.module}/../../bootstrap.sh.tftpl", {
    compose_file    = file("${path.module}/../../../examples/traefik/docker-compose.yml")
    env_file        = local.env_file
    extra_bootstrap = var.extra_bootstrap
  })
}
