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
data "template_file" "cm" {
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

resource "kubernetes_config_map" "example" {
  metadata {
    name = "consul"
  }

  data {
    config.json = "${data.template_file.cm.rendered}"
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

    template {
      metadata {
        labels {
          app = "consul"
        }

        annotations {}
      }

      spec {
        security_context {
          fsGroup = 1000
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

            name = "GOSSIP_ENCRYPTION_KEY"

            value_from {
              secret_key_ref {
                name = "consul"
                key  = "gossip-encryption-key"
              }
            }

            name = "NAMESPACE"

            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
        }
      }
    }
  }
}
