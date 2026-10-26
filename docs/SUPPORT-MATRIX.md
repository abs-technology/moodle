# Support matrix

Pins for the current checkout are in [`versions.lock`](../versions.lock). This table is which Moodle lines this repo still builds. It is not a promise that every historical Hub tag is rebuilt.

| Line | Git branch | Current image | PHP | Base | CVE line | Status |
|------|------------|---------------|-----|------|----------|--------|
| Moodle 5.3 | `moodle-core-5-3` / `main` | `abstechnology/moodle-standard:5.3.0-r5` | 8.4.27 | debian:13-slim | Current. New criticals are patched here first. | Supported |
| Moodle 5.2.3 | `moodle-core-5-2-3` | `abstechnology/moodle-standard:5.2.3-r3` | 8.4.27 | debian:12-slim | Same PHP and client fixes as 5.3, on Bookworm. | Supported |
| Moodle 4.5.15 | `moodle-core-4-5-15` | `abstechnology/moodle-standard:4.5.15-r1` | 8.2.35 | debian:12-slim | Bookworm overlay. New revisions follow the 5.3 process. | Maintenance |
| Moodle 4.3.12 | `moodle-core-4-3-12` | `abstechnology/moodle-standard:4.3.12-r1` | 8.2.35 | debian:12-slim | PHP 8.2.35 and the Bookworm overlay. Moodle 4.3 does not run PHP 8.3+. | Maintenance |

`latest` on Docker Hub is a convenience tag. It is not moved when a revision ships. Pull a versioned tag.

Unsupported as product trunks: `s1`, `s2`, `s3`, `develop`, `develop-5.0.2-plus`, `moodle-standard`, local-only lines that have no `origin/` branch.
