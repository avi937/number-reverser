# Number Reverser

> A tiny HTTP service that reverses integers — wrapped in production-grade infrastructure, a DevSecOps pipeline, and runtime security controls.

**Assignment:** LegitBytes Take-Home Exercise · DevOps Engineer  
**Author:** Avi Arora

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                            │
│                                                                     │
│  app/          → Python Flask API + unit tests                      │
│  Dockerfile    → Multi-stage, non-root, python:3.12-alpine          │
│  terraform/    → Kubernetes resources via Terraform                 │
│  k8s/kyverno/  → Admission-control policies                         │
│  .github/      → DevSecOps CI/CD pipeline (GitHub Actions)          │
└──────────────────────────┬──────────────────────────────────────────┘
                           │  git push to main
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Pipeline                          │
│                                                                     │
│  lint (flake8)                                                      │
│    │                                                                │
│    ├──► unit-test (pytest, >90% coverage)                           │
│    │                                                                │
│    └──► iac-scan (Checkov — blocks on CRITICAL findings)            │
│              │                                                      │
│              ▼                                                      │
│         build image (Docker Buildx → GHCR)                         │
│              │                                                      │
│    ┌─────────┴──────────┐                                           │
│    │                    │                                           │
│    ▼                    ▼                                           │
│  image-scan           sbom                                          │
│  (Trivy — FAIL        (Syft → spdx-json                            │
│   on CRITICAL)         + cyclonedx-json                            │
│    │                   artifact)                                    │
│    └────────┬──────────┘                                            │
│             ▼                                                       │
│          sign (cosign keyless OIDC — no stored keys)                │
│             │                                                       │
│             ▼                                                       │
│          deploy                                                     │
│          1. cosign verify (signature enforced before deploy)        │
│          2. terraform apply → Kubernetes Deployment + NetworkPolicy │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│               kind (Kubernetes in Docker) Cluster                  │
│                                                                     │
│  Namespace: number-reverser                                         │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │  Deployment (2 replicas)                                 │       │
│  │  • non-root user (UID 1000)                              │       │
│  │  • readOnlyRootFilesystem                                │       │
│  │  • capabilities dropped (ALL)                            │       │
│  │  • resource limits enforced (CPU + memory)               │       │
│  │  • no :latest tag (pinned to SHA digest)                 │       │
│  │                                                          │       │
│  │  NetworkPolicy: default-deny + explicit allow rules      │       │
│  │  Kyverno ClusterPolicy: admission control at runtime     │       │
│  └──────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## The Application

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Liveness check → `{"status": "ok"}` |
| `POST` | `/reverse` | Reverse a number via JSON body |
| `GET` | `/reverse?n=12345` | Reverse a number via query string |

### Example

```bash
# POST
curl -X POST http://localhost:8080/reverse \
  -H "Content-Type: application/json" \
  -d '{"n": "12345"}'
# → {"input": "12345", "result": "54321"}

# GET
curl http://localhost:8080/reverse?n=-1200
# → {"input": "-1200", "result": "-21"}
```

### Edge-Case Decisions

| Input | Output | Decision |
|-------|--------|----------|
| `12345` | `54321` | Standard reversal |
| `-123` | `-321` | Sign preserved, digits reversed |
| `1200` | `21` | Trailing zeros become leading zeros → stripped |
| `0` | `0` | Zero is zero |
| `abc` | `422 error` | Non-numeric → rejected with descriptive message |
| `1.5` | `422 error` | Floats are non-numeric for this service |
| `99999999999999999999` | `422 error` | Reversed result overflows 64-bit signed int |

---

## Local Setup

### Prerequisites

- Docker Desktop (with Kubernetes or standalone Docker)
- [kind](https://kind.sigs.k8s.io/) — `choco install kind` or `brew install kind`
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Terraform ≥ 1.6](https://developer.hashicorp.com/terraform/install)
- [cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
- [Syft](https://github.com/anchore/syft#installation)

### Run the app locally (Docker)

```bash
# Build
docker build -t number-reverser:local .

# Run
docker run -p 8080:8080 number-reverser:local

# Test
curl http://localhost:8080/reverse?n=12345
```

### Run unit tests

```bash
cd app
pip install -r requirements.txt -r requirements-dev.txt
pytest test_reverser.py -v --cov=reverser
```

### Spin up local Kubernetes with kind

```bash
# Create cluster
kind create cluster --name number-reverser

# Verify
kubectl cluster-info --context kind-number-reverser
```

### Deploy with Terraform

```bash
# Copy and fill in your values
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Note: S3 backend requires AWS credentials in environment
# or use -backend-config flags. For purely local testing,
# comment out the backend block and use local state.

cd terraform
terraform init
terraform plan
terraform apply
```

### Teardown

```bash
cd terraform
terraform destroy

# Delete the kind cluster
kind delete cluster --name number-reverser
```

> **Cost:** \$0 — kind runs entirely locally inside Docker. No cloud spend.  
> For a managed cluster (EKS/GKE/AKS), replace `config_context` in `variables.tf` and re-apply — no other Terraform changes needed.

---

## GitHub Actions Pipeline Setup

The pipeline uses **only `GITHUB_TOKEN`** for GHCR authentication and cosign OIDC signing — no additional secrets needed for the registry or signing.

The only secrets you need to add in GitHub → Settings → Secrets:

| Secret | Purpose |
|--------|---------|
| `KUBECONFIG` | Base64-encoded kubeconfig for the target cluster |
| `AWS_ACCESS_KEY_ID` | For Terraform S3 backend (remote state) |
| `AWS_SECRET_ACCESS_KEY` | For Terraform S3 backend (remote state) |

> **Why S3 backend?** Storing state locally in CI is dangerous — the next run loses it. S3 + DynamoDB locking is the standard pattern. Credentials are injected via GitHub Secrets (never in code).

---

## Trade-offs & Decisions

| Decision | Alternative | Why I chose this |
|----------|-------------|-----------------|
| **kind** (local K8s) | EKS/GKE/AKS | Zero cost, spins up in 90 seconds, same Terraform resources work on managed clusters |
| **Python Flask** | Go, Node.js | Fastest to write clean, testable code; easy to explain |
| **cosign keyless OIDC** | Long-lived signing keys | No secrets to rotate, no key management, cryptographically verifiable |
| **Kyverno** over OPA/Gatekeeper | OPA | Simpler YAML policies, purpose-built for K8s admission control |
| **Checkov** over tfsec | tfsec | Broader rule set, native SARIF output for GitHub Security tab integration |
| **NetworkPolicy: default-deny** | Allow-all | Least privilege at the network layer; explicit allow rules are easier to audit |
| **gunicorn** over Flask dev server | Flask built-in | Production-grade WSGI; handles signals correctly; not a dev server |

---

## What I'd Add With More Time

- **Managed K8s** (EKS with Fargate or GKE Autopilot) via Terraform for a real cloud environment
- **Vault** or **AWS Secrets Manager** integration for any future app secrets
- **kube-bench** CIS benchmark scan as a job in the pipeline
- **Conftest/OPA** checking `terraform plan` output before `apply` (the optional stretch goal)
- **Horizontal Pod Autoscaler** (HPA) based on CPU metrics
- **Dependabot** alerts for dependency updates
