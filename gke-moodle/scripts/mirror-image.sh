#!/usr/bin/env bash
# Pull the published ABS Moodle image and push it to Artifact Registry
# (required before binary_authorization_enforce = true).
set -euo pipefail

SRC="${SRC:-abstechnology/moodle-standard:5.3.0}"
PROJECT="${PROJECT:?set PROJECT}"
REGION="${REGION:-asia-southeast1}"
REPO="${REPO:-moodle}"
TAG="${TAG:-5.3.0}"

DEST="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/moodle-standard:${TAG}"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
docker pull "$SRC"
docker tag "$SRC" "$DEST"
docker push "$DEST"
echo "Mirrored $SRC -> $DEST"
