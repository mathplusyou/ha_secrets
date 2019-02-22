resource "kubernetes_secret" "vault" {
  metadata {
    name = "vault"
  }

  data {
    ca.pem        = "${file("${var.ca_path}")}"
    vault-key.pem = "${file("${var.vault_key_path}")}"
    vault.pem     = "${file("${var.vault_cert_path}")}"
  }

  depends_on = ["kubernetes_stateful_set.consul"]
}

# VAULT CONFIGMAP
data "template_file" "vault_config" {
  template = <<VAULTCONFIG
{
  "listener": {
    "tcp":{
      "address": "127.0.0.1:8200",
      "tls_disable": 0,
      "tls_cert_file": "/etc/tls/vault.pem",
      "tls_key_file": "/etc/tls/vault-key.pem"
    }
  },
  "storage": {
    "consul": {
      "address": "consul:8500",
      "path": "vault/",
      "disable_registration": "true",
      "ha_enabled": "true"
    }
  },
  "ui": true
}
VAULTCONFIG
}

resource "kubernetes_config_map" "vault" {
  metadata {
    name = "vault"
  }

  data {
    config.json = "${data.template_file.vault_config.rendered}"
  }
}

# VAULT SERVICE
resource "kubernetes_service" "vault" {
  metadata {
    name = "vault"

    labels = {
      app = "vault"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8200
      target_port = 8200
      name        = "vault"
    }

    selector {
      app = "vault"
    }
  }
}

# VAULT DEPLOYMENT
resource "kubernetes_deployment" "vault" {
  metadata {
    name = "vault"

    labels {
      app = "vault"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels {
        app = "vault"
      }
    }

    template {
      metadata {
        labels {
          app = "vault"
        }
      }

      spec {
        container {
          name              = "vault"
          command           = ["vault", "server", "-config", "/vault/config/config.json"]
          image             = "vault:0.11.5"
          image_pull_policy = "IfNotPresent"

          security_context {
            capabilities {
              add = ["IPC_LOCK"]
            }
          }

          volume_mount {
            name       = "configurations"
            mount_path = "/vault/config/config.json"
            sub_path   = "config.json"
          }

          volume_mount {
            name       = "vault"
            mount_path = "/etc/tls"
          }
        }

        container {
          name  = "consul-vault-agent"
          image = "consul:1.4.0"

          env {
            name = "GOSSIP_ENCRYPTION_KEY"

            value_from {
              secret_key_ref {
                name = "consul"
                key  = "gossip-encryption-key"
              }
            }
          }

          env {
            name = "NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          args = ["agent", "-retry-join=consul-0.consul.$(NAMESPACE).svc.cluster.local", "-retry-join=consul-1.consul.$(NAMESPACE).svc.cluster.local", "-retry-join=consul-2.consul.$(NAMESPACE).svc.cluster.local", "-encrypt=$(GOSSIP_ENCRYPTION_KEY)", "-domain=cluster.local", "-datacenter=dc1", "-disable-host-node-id", "-node=vault-1"]

          volume_mount {
            name       = "config"
            mount_path = "/consul/myconfig"
          }

          volume_mount {
            name       = "tls"
            mount_path = "/etc/tls"
          }
        }

        volume {
          name = "configurations"

          config_map {
            name = "vault"
          }
        }

        volume {
          name = "config"

          config_map {
            name = "consul"
          }
        }

        volume {
          name = "tls"

          secret {
            secret_name = "consul"
          }
        }

        volume {
          name = "vault"

          secret {
            secret_name = "vault"
          }
        }
      }
    }
  }

  depends_on = ["kubernetes_service.vault"]
}
