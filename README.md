# SecureVector — EU Terraform Test Harness

Clone-and-run harness that **deploys the SecureVector engine to an EU region via
Terraform, validates it end-to-end, and tears it down.** It exercises the
[#190](https://github.com/Secure-Vector/securevector-ai-threat-monitor) remote-endpoint
path: agents point at a self-hosted, in-region engine via
`SECUREVECTOR_ENGINE_ENDPOINT` instead of a local app.

## What it validates

1. The `terraform-aws-securevector` module deploys cleanly in an EU region.
2. `/health` comes up once the Fargate task pulls the image.
3. **Ingress auth is enforced** — `POST /analyze` is rejected without the token, accepted with it.
4. `/api/system/environment` reports the engine posture.
5. *(optional)* a real LangChain agent run lands in the dashboard, tagged `runtime_kind=langchain`.

## Prerequisites

- Terraform ≥ 1.5, AWS credentials (env vars or a profile), `curl`, `python3`, `openssl`.
- AWS will bill for the Fargate task + ALB while it's up (minutes). The harness destroys everything on exit.

> **⚠️ This is a test harness, not a production template.** By default it deploys an
> **internet-facing HTTP** ALB in the **default VPC** — so a bearer token travels in
> cleartext, and a bare `terraform apply` with **no `ingress_token`** leaves the
> `/analyze` endpoint **open to the internet**. `test.sh` always sets a strong per-run
> token and tears everything down on exit. For anything long-lived: pass a token,
> terminate TLS (ACM/HTTPS) or use an internal ALB / PrivateLink, and deploy into a
> private VPC. The module ref is pinned to an immutable commit for reproducibility.

## Run

```bash
./test.sh                    # deploy in eu-west-1 (Ireland), validate, destroy
REGION=eu-central-1 ./test.sh   # Frankfurt
KEEP=1 ./test.sh             # leave it up to poke around (destroy manually after)
OPENAI_API_KEY=sk-... ./test.sh # also run a live agent against the endpoint
```

## Point your own agent at it

After `terraform apply` (or with `KEEP=1`), grab the endpoint and wire an agent —
the only change from a local setup is the endpoint:

```bash
cd terraform && terraform output -raw dashboard_url   # your engine URL
export SECUREVECTOR_ENGINE_ENDPOINT=<that URL>
export SECUREVECTOR_API_KEY=<ingress_token>           # only if the deploy set one
pip install securevector-sdk-langchain                # add --no-deps if langchain is already installed
python agent/demo_agent.py
```

`terraform output -raw runtime_snippet` prints the exact wiring for the chosen client.

## Data residency (EU)

`terraform/main.tf` pins an EU region and sets `SV_DATA_RESIDENCY=eu`. Every
resource — Fargate task, ALB, EFS volume, logs — is created in that region, so
the resident copy of governance/runtime data stays in-region. On a v4.8+ engine,
`SV_DATA_RESIDENCY=eu` **locks prompt analysis local** (cloud `/analyze` is forced
local), so prompt/output text never leaves the region. Forwarding to a cloud
account (if you connect one) stays metadata-only, and the FULL SIEM tier is
blocked under the EU lock. Deploying in-region is itself the residency lever.

## Layout

```
terraform/main.tf   thin wrapper → terraform-aws-securevector (EU, :4.9.0, residency)
agent/demo_agent.py minimal LangChain agent wired via SECUREVECTOR_ENGINE_ENDPOINT
test.sh             deploy → validate (health/auth/analyze) → destroy
```
