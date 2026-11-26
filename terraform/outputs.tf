output "service_name" {
  description = "Kubernetes Service name."
  value       = kubernetes_service.app.metadata[0].name
}

output "namespace" {
  description = "Kubernetes namespace."
  value       = kubernetes_namespace.app.metadata[0].name
}

output "app_image" {
  description = "Container image deployed."
  value       = var.app_image
}
