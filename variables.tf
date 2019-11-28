variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3a.medium"
}

variable "rancher_version" {
  default = "latest"
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "rancher2_server_admin_password" {}