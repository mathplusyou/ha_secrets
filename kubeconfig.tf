locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.demo.endpoint}
    certificate-authority-data: ${aws_eks_cluster.demo.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

data "template_file" "kubeconfig" {
  template = "${local.kubeconfig}"
}

resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = "echo '${data.template_file.kubeconfig.rendered}' > /Users/ldong/.kube/config"
  }

  depends_on = ["aws_autoscaling_group.demo"]
}

#locals {
#  config_map_aws_auth = <<CONFIGMAPAWSAUTH
#
#
#apiVersion: v1
#kind: ConfigMap
#metadata:
#  name: aws-auth
#  namespace: kube-system
#data:
#  mapRoles: |
#    - rolearn: ${aws_iam_role.demo-node.arn}
#      username: system:node:{{EC2PrivateDNSName}}
#      groups:
#        - system:bootstrappers
#        - system:nodes
#CONFIGMAPAWSAUTH
#}
#
#output "config_map_aws_auth" {
#  value = "${local.config_map_aws_auth}"
#}
#
#data "template_file" "configmap" {
#  template = "${local.config_map_aws_auth}"
#}
#
#resource "null_resource" "configmap" {
#  provisioner "local-exec" {
#    command = "echo '${data.template_file.configmap.rendered}' >> config_map_aws_auth.yaml && kubectl apply -f config_map_aws_auth.yaml"
#  }
#
#  depends_on = ["aws_autoscaling_group.demo"]
#}
#data "external" "aws-iam-authenticator" {
#  program = ["sh", "-c", "aws-iam-authenticator token -i `jq -r .cluster_name` | jq -r -c .status"]
#
#  query = {
#    cluster_name = "${data.terraform_remote_state.eks.cluster_name}"
#  }
#}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data {
    mapRoles = <<YAML
- rolearn: ${aws_iam_role.demo-node.arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
YAML
  }
}
