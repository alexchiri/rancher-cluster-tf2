variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3a.medium"
}

variable "rancher_version" {
  default = "latest"
}

variable "availability_zone" {
  default = "a"
  description = "Which availability zone should be used under the region? This is used exclusively in the rancher2_node_template. Chosen 'a' because that's where there are usually available instances of t3a.medium"
}

variable "kubernetes_version" {
  description = "What version of Kubernetes should it use?"
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "rancher2_server_admin_password" {}