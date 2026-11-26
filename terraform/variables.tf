variable "app_name" {
  description = "Application name used for Kubernetes labels and resource names."
  type        = string
  default     = "number-reverser"
}

variable "app_image" {
  description = "Full container image reference (e.g. ghcr.io/aviArora/number-reverser:sha-abc1234)."
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "replica_count" {
  description = "Number of pod replicas."
  type        = number
  default     = 2
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into."
  type        = string
  default     = "number-reverser"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file. Defaults to ~/.kube/config."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context to use (e.g. kind-number-reverser)."
  type        = string
  default     = "kind-number-reverser"
}

variable "environment" {
  description = "Deployment environment tag (dev / staging / prod)."
  type        = string
  default     = "dev"
}
