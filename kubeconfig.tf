# KUBECONFIG that will be added to ~/.kube/config so that `kubectl` can be used on remote machines to reach the cluster
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
    command = "echo '${data.template_file.kubeconfig.rendered}' > $HOME/.kube/config"
  }

  depends_on = ["aws_autoscaling_group.demo"]
}

# Deploy ConfigMap for worker nodes to be automatically added to the cluster
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
