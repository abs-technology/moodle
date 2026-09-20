# Path is set by scripts/tf-init.sh:
#   -backend-config=path=.states/<live project_id>/terraform.tfstate
# Do not apply this root by hand — project_id lives in terraform/live only.
terraform {
  backend "local" {}
}
