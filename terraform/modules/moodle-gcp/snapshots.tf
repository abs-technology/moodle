# GCP snapshot start_time is UTC only. Asia/Ho_Chi_Minh is UTC+7 with no DST,
# so 22:00 local is 15:00 UTC. The policy name records the local clock.
locals {
  timezone_utc_offset = {
    "Asia/Ho_Chi_Minh" = 7
  }
  snapshot_hour_local = 22
  snapshot_utc_hour   = (local.snapshot_hour_local - local.timezone_utc_offset[var.timezone] + 24) % 24
  snapshot_utc_hhmm   = format("%02d:00", local.snapshot_utc_hour)
}

resource "google_compute_resource_policy" "weekly" {
  count  = var.snapshot_weekly ? 1 : 0
  name   = "${var.name}-sun-22-ict"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      weekly_schedule {
        day_of_weeks {
          day        = "SUNDAY"
          start_time = local.snapshot_utc_hhmm
        }
      }
    }

    retention_policy {
      max_retention_days    = var.snapshot_retain_weeks * 7
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      storage_locations = [var.region]
      guest_flush       = false
    }
  }

  depends_on = [google_project_service.compute]
}

# Boot disks created with initialize_params are named after the instance.
resource "google_compute_disk_resource_policy_attachment" "weekly" {
  count = var.snapshot_weekly ? 1 : 0
  name  = google_compute_resource_policy.weekly[0].name
  disk  = google_compute_instance.moodle.name
  zone  = var.zone
}
