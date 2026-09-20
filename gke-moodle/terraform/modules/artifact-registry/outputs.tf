output "repository" {
  value = google_artifact_registry_repository.moodle.name
}

output "image_prefix" {
  value = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
