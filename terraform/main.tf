###############################################################################
# SecureVector EU terraform test harness — AWS
#
# Thin wrapper around the terraform-aws-securevector module, pinned to an EU
# region for data residency and to a released engine image. Used to spin up a
# real engine, validate the endpoint + agent forwarding + auth + residency, then
# tear it down (see ../test.sh).
#
#   terraform init
#   terraform apply -var="ingress_token=$(openssl rand -hex 24)"
#   terraform output -raw dashboard_url
#   terraform destroy
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

variable "region" {
  type        = string
  default     = "eu-west-1" # Ireland; use eu-central-1 for Frankfurt
  description = "EU AWS region. All module resources are created here, so this governs data residency."
}

variable "engine_image" {
  type        = string
  default     = "ghcr.io/secure-vector/securevector-ai-threat-monitor:4.9.0"
  description = "Engine image to deploy. Pinned to a released tag for reproducible tests."
}

variable "ingress_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "If set, the engine REQUIRES this token on every inbound request (Authorization: Bearer / X-Api-Key). Leave empty to test the open path."
}

provider "aws" {
  region = var.region
}

module "securevector" {
  # Pinned to an immutable commit (the v4.9 / #190 unified-endpoint release of the
  # module) for reproducible, supply-chain-safe deploys. Bump deliberately.
  source = "github.com/Secure-Vector/terraform-aws-securevector?ref=bcab32b3c836f3142150b7cfb33a85d7d685eb3a"

  name                 = "sv-eu-test"
  image                = var.engine_image
  securevector_runtime = "langchain" # emits a copy-paste client snippet as output

  # Cheapest TEST posture: single task, default VPC/public subnets, internet-facing
  # HTTP (no TLS). Fine for this deploy→validate→destroy harness, NOT for anything
  # long-lived: a bearer token over plain HTTP is exposed in transit. For real use,
  # front the ALB with ACM/HTTPS (or an internal ALB / PrivateLink) and a private VPC.
  min_instances = 1
  max_instances = 1

  # Inbound auth. test.sh always sets a strong per-run token. NOTE: the var defaults
  # to "" — a bare `terraform apply` with no -var deploys an OPEN internet-facing
  # /analyze endpoint. Always pass a token (see the header) unless you intend that.
  ingress_token = var.ingress_token

  # EU data residency: keep ALL prompt analysis local even with Cloud Mode on
  # (v4.8+ engine locks local-only analysis; cloud /analyze is forced local).
  extra_env = { SV_DATA_RESIDENCY = "eu" }
}

output "dashboard_url" { value = module.securevector.dashboard_url }
output "health_url" { value = module.securevector.health_url }
output "region" { value = module.securevector.region }
output "runtime_snippet" { value = module.securevector.runtime_snippet }
