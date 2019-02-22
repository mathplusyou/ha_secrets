resource "kubernetes_secret" "vault" {
  metadata {
    name = "vault"
  }

  data {
    ca.pem         = "${file("${var.ca_path}")}"
    consul-key.pem = "${file("${var.vault_key_path}")}"
    consul.pem     = "${file("${var.vault_cert_path}")}"
  }

  depends_on = ["kubernetes_stateful_set.consul"]
}
