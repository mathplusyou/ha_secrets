data "aws_eks_cluster_auth" "token" {
  name = "${aws_eks_cluster.demo.name}"
}

provider "kubernetes" {
  host                   = "${aws_eks_cluster.demo.endpoint}"
  cluster_ca_certificate = "${base64decode("${aws_eks_cluster.demo.certificate_authority.0.data}")}"
  token                  = "${data.aws_eks_cluster_auth.token.token}"

  # token                  = "k8s-aws-v1.aHR0cHM6Ly9zdHMuYW1hem9uYXdzLmNvbS8_QWN0aW9uPUdldENhbGxlcklkZW50aXR5JlZlcnNpb249MjAxMS0wNi0xNSZYLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFKSjdSTTNPSEtHRVhaRlBBJTJGMjAxOTAyMjIlMkZ1cy1lYXN0LTElMkZzdHMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDE5MDIyMlQwMDAwNDVaJlgtQW16LUV4cGlyZXM9MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QlM0J4LWs4cy1hd3MtaWQmWC1BbXotU2lnbmF0dXJlPWIwYTQ1NDc5OThhMzA5MTlkMzg4MjU0NWIzNjgzZDkzNWIwODE4YTBhMWNhYWQ5ZWQxMjEyOWRlYmVlZWJmNTQ"
  load_config_file = false

  #  client_certificate     = ""  #  client_key             = ""
}

resource "kubernetes_pod" "nginx" {
  metadata {
    name = "lynnux"

    labels {
      App = "nginx"
    }
  }

  spec {
    container {
      image = "nginx:1.7.8"
      name  = "example"

      port {
        container_port = 80
      }
    }
  }

  depends_on = ["kubernetes_config_map.aws_auth"]
}
