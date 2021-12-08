terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_security_group" "allow-rdp" {
  name = "allow-rdp"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${var.ip}"]
  }

  tags = {
    Name = "allow_RDP"
  }

}
resource "aws_instance" "app_server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = ["${aws_security_group.allow-rdp.id}"]
  get_password_data      = "true"
  key_name               = "dn"
  tags = {
    Name = var.name,
    Bkp  = "always"
  }
}
resource "aws_instance" "app_server2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = ["${aws_security_group.allow-rdp.id}"]
  get_password_data      = "true"
  key_name               = "dn"
  tags = {
    Name = var.name,
    Bkp  = "always"
  }
}
resource "aws_s3_bucket" "b" {
  bucket = var.bucketname
  acl    = "private"

  tags = {
    Name        = var.bucketname
    Environment = "Dev"
  }
}
resource "aws_launch_template" "wintemp" {
  name_prefix   = "wintemp"
  image_id      = var.ami
  instance_type = var.instance_type
  key_name = "dn"
}
resource "aws_autoscaling_group" "winapp" {
  availability_zones = ["${var.region}a"]
  desired_capacity   = 2
  max_size           = 2
  min_size           = 1

  launch_template {
    id      = "${aws_launch_template.wintemp.id}"
    version = "$Latest"
  }
}