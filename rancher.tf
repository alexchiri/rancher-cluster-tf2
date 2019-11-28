//locals {
//  cluster_id_tag = {
//    "kubernetes.io/cluster/${rancher2_cluster.cluster.id}" = "owned"
//  }
//}

provider "null" {}

resource "null_resource" "delay" {
  depends_on = [aws_instance.rancherserver]

  provisioner "local-exec" {
    command = "sleep 100"
  }
}

provider "rancher2" {
  alias = "bootstrap"

  api_url   = "https://${aws_instance.rancherserver.public_dns}"
  bootstrap = true
  insecure = true
}

# Create a new rancher2_bootstrap using bootstrap provider config
resource "rancher2_bootstrap" "admin" {
  provider = rancher2.bootstrap

  password = var.rancher2_server_admin_password
  telemetry = true
  depends_on = [null_resource.delay]
}

# Provider config for admin
provider "rancher2" {
  alias = "admin"

  api_url = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
  insecure = true
}

resource "rancher2_cluster" "cluster" {
  provider = rancher2.admin

  name = "rancher-${formatdate("YYYY-MM-DD-hh-mm-ss",timestamp())}"
  description = "Just a Rancher test cluster created at ${timestamp()}"
  rke_config {
    cloud_provider {
      name = "aws"
    }

    authentication {
      strategy = "x509"

//      sans = [
//        aws_instance.rancherserver.public_ip
//      ]
    }

    authorization {
      mode = "rbac"
    }

    network {
      plugin = "calico"
    }
  }
}


# Create a new rancher2 Node Template
resource "rancher2_node_template" "node_template" {
  provider = rancher2.admin

  name = "rancher-node-template"
  description = "Node template used for the Rancher nodes"
  amazonec2_config {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    ami =  data.aws_ami.ubuntu.id
    region = var.region
    security_group = [aws_security_group.allow-all.name]
    subnet_id = aws_default_subnet.default.id
    vpc_id = aws_default_subnet.default.vpc_id
    zone = "a"
    instance_type = var.instance_type
    iam_instance_profile = aws_iam_instance_profile.rke-aws.name
  }
}
# Create a new rancher2 Node Pool
resource "rancher2_node_pool" "controlplane_node_pool" {
  provider = rancher2.admin

  cluster_id =  rancher2_cluster.cluster.id
  name = "rancher-controlplane-node-pool"
  hostname_prefix =  "rancher-controlplane"
  node_template_id = rancher2_node_template.node_template.id
  quantity = 1
  control_plane = true
  etcd = true
  worker = false
}

resource "rancher2_node_pool" "worker_node_pool" {
  provider = rancher2.admin

  cluster_id =  rancher2_cluster.cluster.id
  name = "rancher-worker-node-pool"
  hostname_prefix =  "rancher-worker"
  node_template_id = rancher2_node_template.node_template.id
  quantity = 2
  control_plane = false
  etcd = false
  worker = true
}

resource "local_file" "kube_cluster_yaml" {
  filename = "./kube_config_cluster.yml"
  content  = rancher2_cluster.cluster.kube_config

  provisioner "local-exec" {
    command = "cp -f ./kube_config_cluster.yml ~/.kube/kubeconfig"
  }
}