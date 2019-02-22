# grab the token from the EKS cluster 
data "aws_eks_cluster_auth" "token" {
  name = "${aws_eks_cluster.demo.name}"
}

provider "kubernetes" {
  host                   = "${aws_eks_cluster.demo.endpoint}"
  cluster_ca_certificate = "${base64decode("${aws_eks_cluster.demo.certificate_authority.0.data}")}"
  token                  = "${data.aws_eks_cluster_auth.token.token}"

  load_config_file = false
}
