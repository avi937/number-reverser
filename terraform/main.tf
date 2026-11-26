# ============================================================
# Kubernetes resources — all managed via Terraform
# ============================================================

# ---- Namespace -------------------------------------------
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
}

# ---- Deployment ------------------------------------------
resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = var.app_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = var.app_name
          version                  = "stable"
        }
        # Annotations tell Kyverno / OPA which policies apply
        annotations = {
          "seccomp.security.alpha.kubernetes.io/pod" = "runtime/default"
        }
      }

      spec {
        # Security best-practice: do NOT run as root
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        # Disable service-account token auto-mount (not needed)
        automount_service_account_token = false

        container {
          name  = var.app_name
          image = var.app_image

          # Never use :latest — image is pinned to a digest in CI
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.app_port
            protocol       = "TCP"
          }

          # Container-level security hardening
          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            run_as_user                = 1000
            capabilities {
              drop = ["ALL"]
            }
          }

          # Resource limits prevent noisy-neighbour / DoS impact
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          # Health probes so K8s knows if the pod is ready/alive
          liveness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }

          # Writable temp dir for gunicorn (read-only root fs requires this)
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }
      }
    }
  }
}

# ---- Service --------------------------------------------
resource "kubernetes_service" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = var.app_name
    }

    port {
      port        = 80
      target_port = var.app_port
      protocol    = "TCP"
    }

    type = "ClusterIP" # Not exposed to the internet directly
  }
}

# ---- NetworkPolicy: default-deny then allow only needed traffic --
resource "kubernetes_network_policy" "default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {} # applies to ALL pods in namespace

    policy_types = ["Ingress", "Egress"]
    # No ingress/egress rules = deny everything by default
  }
}

resource "kubernetes_network_policy" "allow_app_ingress" {
  metadata {
    name      = "allow-app-ingress"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = var.app_name
      }
    }

    policy_types = ["Ingress"]

    ingress {
      ports {
        port     = tostring(var.app_port)
        protocol = "TCP"
      }
      # Allow from any pod in the same namespace (adjust to specific labels in prod)
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = var.namespace
          }
        }
      }
    }
  }
}

resource "kubernetes_network_policy" "allow_app_egress_dns" {
  metadata {
    name      = "allow-egress-dns"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = var.app_name
      }
    }

    policy_types = ["Egress"]

    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
  }
}
