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
  source = "github.com/Secure-Vector/terraform-aws-securevector?ref=main"

  name                 = "sv-eu-test"
  image                = var.engine_image
  securevector_runtime = "langchain" # emits a copy-paste client snippet as output

  # Cheapest test posture: single task, default VPC/subnets, public HTTP.
  min_instances = 1
  max_instances = 1

  # Optional inbound auth — when set, every client must forward the token.
  ingress_token = var.ingress_token

  # EU data residency: keep ALL prompt analysis local even with Cloud Mode on
  # (v4.8+ engine locks local-only analysis; cloud /analyze is forced local).
  extra_env = { SV_DATA_RESIDENCY = "eu" }
}

output "dashboard_url" { value = module.securevector.dashboard_url }
output "health_url" { value = module.securevector.health_url }
output "region" { value = module.securevector.region }
output "runtime_snippet" { value = module.securevector.runtime_snippet }
