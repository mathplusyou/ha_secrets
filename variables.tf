variable "cluster-name" {
  default = "ld"
  type    = "string"
}

variable "gossip_key" {}

variable "ca_path" {}
variable "consul_key_path" {}
variable "consul_cert_path" {}
variable "vault_key_path" {}
variable "vault_cert_path" {}
