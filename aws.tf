provider "aws" {
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_default_subnet" "default" {
  availability_zone = "us-east-1a"
}


resource "aws_security_group" "allow-all" {
  name        = "rke-default-security-group"
  description = "rke"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //  tags = local.cluster_id_tag
}

resource "tls_private_key" "node-key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "rke-node-key" {
  key_name   = "rke-node-key"
  public_key = tls_private_key.node-key.public_key_openssh
}

output "private_key" {
  value = tls_private_key.node-key.private_key_pem
}

# Step 1: Create an IAM role
resource "aws_iam_role" "rke-role" {
  name = "rke-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF

}

# Step 2: Add our Access Policy
resource "aws_iam_role_policy" "rke-access-policy" {
  name = "rke-access-policy"
  role = aws_iam_role.rke-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AttachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DetachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:*"],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": ["elasticloadbalancing:*"],
      "Resource": ["*"]
    }
  ]
}
EOF

}

# Step 3: Create the Instance Profile
resource "aws_iam_instance_profile" "rke-aws" {
  name = "rke-aws"
  role = aws_iam_role.rke-role.name
}


data "template_cloudinit_config" "rancherserver-cloudinit" {
  part {
    content_type = "text/cloud-config"
    content      = "hostname: rancherserver\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.userdata_server.rendered
  }
}

data "template_file" "userdata_server" {
  template = file("install-docker.sh")

  vars = {
    rancher_version       = var.rancher_version
  }
}

resource "aws_instance" "rancherserver" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.rke-node-key.id
  iam_instance_profile   = aws_iam_instance_profile.rke-aws.name
  vpc_security_group_ids = [aws_security_group.allow-all.id]
  user_data       = data.template_cloudinit_config.rancherserver-cloudinit.rendered

  tags = {
    Name = "rancherserver"
  }
}