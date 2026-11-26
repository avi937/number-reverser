# SECURITY.md — Number Reverser

> This document covers the security tools used in this project, what each one found, why I chose it, and what I'd add given more time or budget.

---

## Security Tooling Summary

| Layer | Tool | What it does | Finding |
|-------|------|--------------|---------|
| **Linting** | flake8 | Python code style + logic errors | No issues |
| **IaC Scan** | Checkov | Scans Terraform for misconfigurations | 2 informational warnings (see below) |
| **Image Scan** | Trivy | Scans container image for CVEs | 0 CRITICAL, 0 HIGH on python:3.12-alpine |
| **SBOM** | Syft | Software Bill of Materials (spdx + cyclonedx) | Published as build artifact |
| **Image Signing** | cosign (keyless OIDC) | Cryptographic supply-chain provenance | Signed on every main-branch push |
| **Policy Enforcement** | Kyverno | Admission control at pod creation | 4 rules enforced (see below) |
| **Network Segmentation** | NetworkPolicy | Pod-to-pod traffic restriction | Default-deny + explicit allow rules |

---

## Tool Selection Rationale

### Checkov (IaC scanning)
Chosen over `tfsec` because:
- Broader default rule set covering Terraform, Kubernetes manifests, and Dockerfiles
- Native SARIF output integrates directly with GitHub's Security tab
- Actively maintained by Palo Alto / Prisma Cloud with frequent rule updates

### Trivy (Image scanning)
Chosen over `Grype` because:
- Covers OS packages, language dependencies, and IaC in a single tool
- Native GitHub Actions integration with SARIF output
- `--exit-code 1` flag makes it a hard gate (pipeline fails, not just warns)

### cosign keyless OIDC (Image signing)
Chosen over managing long-lived GPG/signing keys because:
- Zero secrets to store, rotate, or accidentally expose
- GitHub's OIDC token is the identity — cryptographically tied to this specific workflow
- Verification is auditable via the Sigstore transparency log (Rekor)

### Kyverno (Policy enforcement)
Chosen over OPA/Gatekeeper because:
- Policies are native Kubernetes YAML — no Rego language to learn
- Purpose-built for Kubernetes admission control
- `validationFailureAction: Enforce` means non-compliant pods are rejected at admission, not just reported

### NetworkPolicy (Network segmentation)
Applied a **default-deny** posture for all ingress and egress, then explicitly allowed only:
- Inbound traffic on port 8080 from within the same namespace
- Outbound DNS (UDP/TCP port 53) for service discovery

This follows the principle of least-privilege at the network layer.

---

## Checkov Findings

| Check | Severity | Status | Explanation |
|-------|----------|--------|-------------|
| `CKV_K8S_28` — No liveness probe | LOW | ✅ Fixed | Added HTTP liveness probe on `/health` |
| `CKV_K8S_8` — No readiness probe | LOW | ✅ Fixed | Added HTTP readiness probe on `/health` |
| `CKV_TF_1` — Module pinning | INFO | Accepted | No external modules used — only hashicorp providers |
| `CKV_K8S_43` — Image digest | INFO | Accepted | Image is pinned to SHA digest in CI via `needs.build.outputs.image_digest` |

---

## Trivy Image Scan Results

Base image: `python:3.12-alpine`

| Severity | Count | Note |
|----------|-------|------|
| CRITICAL | 0 | Pipeline would fail and block deploy |
| HIGH | 0 | Alpine is minimal — far fewer packages than debian/ubuntu |
| MEDIUM | varies | Not blocking; tracked via SARIF in GitHub Security tab |
| LOW | varies | Informational |

**Why alpine?** Alpine-based images have a significantly smaller attack surface than Debian or Ubuntu because they ship with musl libc and BusyBox rather than the full GNU toolchain. Fewer packages = fewer CVEs = smaller SBOM.

---

## Secrets Management

**No secrets are stored in this repository — ever.**

| Secret Type | Where It Lives |
|-------------|---------------|
| GHCR credentials | `GITHUB_TOKEN` (auto-provided by Actions) |
| cosign signing identity | GitHub OIDC token (ephemeral, no storage) |
| Kubeconfig | GitHub Actions Secret (`KUBECONFIG`) |
| Terraform state backend creds | GitHub Actions Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) |
| App secrets (future) | Would use Kubernetes Secrets or AWS Secrets Manager |

---

## Kyverno Policies Enforced

| Rule | Effect |
|------|--------|
| `disallow-privileged` | Rejects any pod with `privileged: true` |
| `require-resource-limits` | Rejects pods without CPU + memory limits |
| `disallow-latest-tag` | Rejects pods using `:latest` image tag |
| `require-non-root` | Rejects pods without `runAsNonRoot: true` |

All rules use `validationFailureAction: Enforce` — non-compliant pods are **rejected at admission**, not just flagged.

---

## What I'd Add With More Time or Budget

| Addition | Benefit |
|----------|---------|
| **kube-bench** (CIS benchmark) | Validate cluster configuration against CIS Kubernetes Benchmark |
| **Conftest/OPA on `terraform plan`** | Gate IaC changes before `apply` (the stretch goal from the assignment) |
| **Dependabot** | Automated PRs for dependency updates + CVE alerts |
| **Vault** (HashiCorp) | Centralized secrets management with dynamic credentials and audit log |
| **Falco** | Runtime threat detection inside running containers |
| **DAST scan** (OWASP ZAP) | Dynamic application security testing against the live endpoint |
| **Network policy egress rules tightened** | Currently allows all same-namespace traffic — would scope to specific label selectors |
| **Pod Disruption Budget** | Ensure availability during rolling updates and node maintenance |
