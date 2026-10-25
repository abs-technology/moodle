#!/usr/bin/env bash
# Wait until each node-pool MIG has MIN_PER_ZONE RUNNING VMs.
# Used by terraform_data.wait_nodes — gcloud only (no kubectl plugin).
set -euo pipefail

: "${PROJECT:?}" "${CLUSTER:?}" "${REGION:?}" "${POOL:?}"
: "${MIN_PER_ZONE:?}" "${MIN_TOTAL:?}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"

deadline=$((SECONDS + TIMEOUT_SECONDS))

nodes_ready() {
  python3 - "$PROJECT" "$CLUSTER" "$REGION" "$POOL" "$MIN_PER_ZONE" "$MIN_TOTAL" <<'PY'
import json, subprocess, sys

project, cluster, region, pool, min_pz, min_total = sys.argv[1:7]
min_pz, min_total = int(min_pz), int(min_total)


def gcloud(*args):
    return subprocess.check_output(["gcloud", *args], text=True)


pool_desc = json.loads(
    gcloud(
        "container",
        "node-pools",
        "describe",
        pool,
        f"--cluster={cluster}",
        f"--region={region}",
        f"--project={project}",
        "--format=json",
    )
)
urls = pool_desc.get("instanceGroupUrls") or pool_desc.get("managedInstanceGroupUrls") or []
if not urls:
    cluster_desc = json.loads(
        gcloud(
            "container",
            "clusters",
            "describe",
            cluster,
            f"--region={region}",
            f"--project={project}",
            "--format=json",
        )
    )
    n = int(cluster_desc.get("currentNodeCount") or 0)
    print(f"  currentNodeCount={n} (need {min_total})", file=sys.stderr)
    sys.exit(0 if n >= min_total else 1)

ok_zones = 0
total_running = 0
for url in urls:
    parts = url.rstrip("/").split("/")
    try:
        zone = parts[parts.index("zones") + 1]
        name = parts[parts.index("instanceGroupManagers") + 1]
    except ValueError:
        print(f"  unparsed MIG url: {url}", file=sys.stderr)
        sys.exit(1)
    ig = json.loads(
        gcloud(
            "compute",
            "instance-groups",
            "managed",
            "describe",
            name,
            f"--zone={zone}",
            f"--project={project}",
            "--format=json",
        )
    )
    target = int(ig.get("targetSize") or 0)
    inst = json.loads(
        gcloud(
            "compute",
            "instance-groups",
            "managed",
            "list-instances",
            name,
            f"--zone={zone}",
            f"--project={project}",
            "--format=json",
        )
        or "[]"
    )
    running = sum(1 for i in inst if i.get("instanceStatus") == "RUNNING")
    print(f"  {zone}: running={running} target={target} (need {min_pz})", file=sys.stderr)
    if running >= min_pz:
        ok_zones += 1
    total_running += running

print(
    f"  zones_ready={ok_zones}/{len(urls)} running_total={total_running}",
    file=sys.stderr,
)
sys.exit(0 if ok_zones == len(urls) and total_running >= min_total else 1)
PY
}

echo "==> waiting for GKE ${CLUSTER}/${POOL}: ${MIN_TOTAL} nodes (${MIN_PER_ZONE}/zone)"
# minNodeCount only blocks scale-down. CA will not raise MIG target from 0
# without pending resource demand — resize to the per-zone floor if short.
if ! nodes_ready; then
  echo "==> resizing ${CLUSTER}/${POOL} to ${MIN_PER_ZONE} node(s) per zone"
  gcloud container clusters resize "${CLUSTER}" \
    --project="${PROJECT}" \
    --region="${REGION}" \
    --node-pool="${POOL}" \
    --num-nodes="${MIN_PER_ZONE}" \
    --quiet
fi

while ((SECONDS < deadline)); do
  if nodes_ready; then
    echo "==> GKE nodes ready"
    exit 0
  fi
  sleep 15
done

echo "timeout after ${TIMEOUT_SECONDS}s waiting for ${MIN_TOTAL} nodes on ${CLUSTER}/${POOL}" >&2
exit 1
