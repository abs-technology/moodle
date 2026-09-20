# Independent of the VM terraform/ tree.
#   make init && make apply          # GCP infra
#   docs/DEPLOY.md                   # Helm Moodle (manual)

TFDIR := terraform/live
TF    := terraform

.PHONY: help init plan apply destroy output outputs kubeconfig mirror fmt validate sync-overlays preflight

help:
	@echo "GKE Moodle — run from this directory (gke-moodle/)"
	@echo ""
	@echo "  make init         ADC + live project_id → state bucket, then terraform init live"
	@echo "  make plan         terraform plan live (GCP infra only)"
	@echo "  make preflight    leftover names + scheduled-deletion secrets"
	@echo "  make apply        terraform apply live (20–40 min first time)"
	@echo "  make output       print IPs, connect, helm_values"
	@echo "  make kubeconfig   gcloud get-credentials (needs gke-gcloud-auth-plugin)"
	@echo "  make destroy      terraform destroy live (keeps the state bucket)"
	@echo "  make validate     overlay drift check + terraform validate + helm lint"
	@echo "  make sync-overlays copy Hub overlay scripts into the Helm chart"
	@echo "  make fmt          terraform fmt + helm lint"
	@echo "  make mirror PROJECT=my-proj   copy image to Artifact Registry"
	@echo ""
	@echo "App install is manual: docs/DEPLOY.md"
	@echo "Before apply: edit terraform/live/terraform.tfvars (project_id)."
	@echo "ADC: gcloud auth application-default login"

init:
	./scripts/tf-init.sh

preflight:
	./scripts/preflight-apply.sh

plan:
	$(TF) -chdir=$(TFDIR) plan

apply:
	$(TF) -chdir=$(TFDIR) apply

destroy:
	$(TF) -chdir=$(TFDIR) destroy

output outputs:
	$(TF) -chdir=$(TFDIR) output

kubeconfig:
	@eval "$$($(TF) -chdir=$(TFDIR) output -raw connect)"

mirror:
	PROJECT="$(PROJECT)" REGION="$(REGION)" ./scripts/mirror-image.sh

fmt:
	$(TF) fmt -recursive terraform
	helm lint charts/moodle

sync-overlays:
	./scripts/sync-hub-overlays.sh

validate:
	./scripts/sync-hub-overlays.sh --check
	$(TF) -chdir=$(TFDIR) validate
	helm lint charts/moodle
