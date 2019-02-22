resource "kubernetes_secret" "consul" {
  metadata {
    name = "consul"
  }

  data {
    ca.pem         = "${file("${var.ca_path}")}"
    consul-key.pem = "${file("${var.consul_key_path}")}"
    consul.pem     = "${file("${var.consul_cert_path}")}"

    gossip-encryption-key = "${var.gossip_key}"
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}

# CONSUL CONFIGMAP
data "template_file" "consul_config" {
  template = <<CONSULCONFIG
{
  "ca_file": "/etc/tls/ca.pem",
  "cert_file": "/etc/tls/consul.pem",
  "key_file": "/etc/tls/consul-key.pem",
  "verify_incoming": true,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ports": {
    "https": 8443
  }
}
CONSULCONFIG
}

resource "kubernetes_config_map" "consul" {
  metadata {
    name = "consul"
  }

  data {
    config.json = "${data.template_file.consul_config.rendered}"
  }
}

# CONSUL SERVICE to expose each of the Consul members internally
resource "kubernetes_service" "consul" {
  metadata {
    name = "consul"

    labels = {
      name = "consul"
    }
  }

  spec {
    selector {
      app = "consul"
    }

    cluster_ip = "None" # Headless service

    port = {
      name        = "http"
      port        = 8500
      target_port = 8500
    }

    port = {
      name        = "https"
      port        = 8443
      target_port = 8443
    }

    port = {
      name        = "rpc"
      port        = 8400
      target_port = 8400
    }

    port = {
      name        = "serflan-tcp"
      port        = 8301
      target_port = 8301
    }

    port = {
      name        = "serfwan-tcp"
      port        = 8302
      target_port = 8302
    }

    port = {
      name        = "serflan-udp"
      protocol    = "UDP"
      port        = 8301
      target_port = 8301
    }

    port = {
      name        = "serfwan-udp"
      protocol    = "UDP"
      port        = 8302
      target_port = 8302
    }

    port = {
      name        = "server"
      port        = 8300
      target_port = 8300
    }

    port = {
      name        = "consuldns"
      port        = 8600
      target_port = 8600
    }
  }
}

## CONSUL STATEFULSET
resource "kubernetes_stateful_set" "consul" {
  metadata {
    name = "consul"
  }

  spec {
    service_name = "consul"
    replicas     = 3

    selector {
      match_labels {
        app = "consul"
      }
    }

    template {
      metadata {
        labels {
          app = "consul"
        }

        annotations {}
      }

      spec {
        security_context {
          fs_group = 1000
        }

        container {
          name  = "consul"
          image = "consul:1.4.0"

          env {
            name = "POD_IP"

            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

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

          args = ["agent", "-advertise=$(POD_IP)", "-bind=0.0.0.0", "-bootstrap-expect=3", "-retry-join=consul-0.consul.$(NAMESPACE).svc.cluster.local", "-retry-join=consul-1.consul.$(NAMESPACE).svc.cluster.local", "-retry-join=consul-2.consul.$(NAMESPACE).svc.cluster.local", "-client=0.0.0.0", "-config-file=/consul/myconfig/config.json", "-datacenter=dc1", "-data-dir=/consul/data", "-domain=cluster.local", "-encrypt=$(GOSSIP_ENCRYPTION_KEY)", "-server", "-ui", "-disable-host-node-id"]

          volume_mount {
            name       = "config"
            mount_path = "/consul/myconfig"
          }

          volume_mount {
            name       = "tls"
            mount_path = "/etc/tls"
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "consul leave"]
              }
            }
          }

          port {
            container_port = 8500
            name           = "ui-port"
          }

          port {
            container_port = 8400
            name           = "alt-port"
          }

          port {
            container_port = 53
            name           = "udp-port"
          }

          port {
            container_port = 8443
            name           = "https-port"
          }

          port {
            container_port = 8080
            name           = "http-port"
          }

          port {
            container_port = 8301
            name           = "serflan"
          }

          port {
            container_port = 8302
            name           = "serfwan"
          }

          port {
            container_port = 8600
            name           = "consuldns"
          }

          port {
            container_port = 8300
            name           = "server"
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
      }
    }
  }
}
