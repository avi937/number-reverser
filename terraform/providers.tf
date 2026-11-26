# ============================================================
# Terraform — Number Reverser on Kubernetes (kind / local)
# ============================================================
# Strategy: We use the Terraform `kubernetes` provider to deploy
# the app into a local `kind` cluster. This keeps cost at $0 and
# lets the pipeline run entirely in GitHub Actions with no cloud
# credentials needed for the K8s layer.
#
# For a production environment, replace `config_path` with
# a kubeconfig from EKS / GKE / AKS — Terraform resources
# (Deployment, Service, NetworkPolicy) are provider-agnostic.
# ============================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }

  # Remote state — stored in an S3-compatible backend.
  # Credentials are injected via environment variables
  # (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) — never hardcoded.
  backend "s3" {
    bucket         = "number-reverser-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# ---- Kubernetes provider ----------------------------------
# kubeconfig is loaded from the KUBECONFIG env var in CI,
# or from `~/.kube/config` locally after `kind create cluster`.
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
