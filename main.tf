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
resource "aws_security_group" "allow-ssh" {
  name = "allow-ssh"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ip}"]
  }

  tags = {
    Name = "allow_ssh"
  }

}
resource "aws_instance" "app_server" {
  ami                    = var.ami
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.test_profile.name
  vpc_security_group_ids = ["${aws_security_group.allow-rdp.id}"]
  get_password_data      = "true"
  key_name               = "dn"
  tags = {
    Name = var.name,
    Bkp  = "always"
  }
}
resource "aws_instance" "app_server2" {
  ami                    = "ami-0d0af2e0be277a70d"
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.test_profile.name
  vpc_security_group_ids = ["${aws_security_group.allow-rdp.id}"]
  get_password_data      = "true"
  key_name               = "dn"
  tags = {
    Name = "Win2012",
    Bkp  = "always"
  }
}
resource "aws_instance" "rhel1" {
  ami                    = "ami-0b0af3577fe5e3532"
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.test_profile.name
  vpc_security_group_ids = ["${aws_security_group.allow-rdp.id}", "${aws_security_group.allow-ssh.id}"]
  key_name               = "dn"
  user_data              = <<EOF
  #!/bin/bash
  cd /tmp
  sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  sudo systemctl enable amazon-ssm-agent
  sudo systemctl start amazon-ssm-agent


  EOF
  tags = {
    Name = "Linux",
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
resource "aws_cloudwatch_log_group" "rebootsfn" {
  name = "rebootsfn"

  tags = {
    Environment = "production"
    Application = "Reboot State Machine"
  }
}
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "Reboot"
  role_arn = aws_iam_role.state.arn
  type     = "STANDARD"
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.rebootsfn.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "StopInstances",
  "States": {
    "StopInstances": {
      "Type": "Task",
      "Parameters": {
        "InstanceIds": [
          "${aws_instance.rhel1.id}"
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:stopInstances",
      "Next": "Wait"
    },
    "Wait": {
      "Type": "Wait",
      "Seconds": 120,
      "Next": "StartInstances"
    },
    "StartInstances": {
      "Type": "Task",
      "Parameters": {
        "InstanceIds": [
          "${aws_instance.rhel1.id}"
        ]
      },
      "Resource": "arn:aws:states:::aws-sdk:ec2:startInstances",
      "Next": "Wait for Reboot"
    },
    "Wait for Reboot": {
      "Type": "Wait",
      "Seconds": 120,
      "Next": "SendCommand"
    },
    "SendCommand": {
      "Type": "Task",
      "Parameters": {
        "DocumentName": "AWS-RunShellScript",
        "DocumentVersion": "1",
        "InstanceIds": [
          "${aws_instance.rhel1.id}"
        ],
        "MaxConcurrency": "50",
        "MaxErrors": "50",
        "OutputS3BucketName": "${var.bucketname}",
        "OutputS3KeyPrefix": "",
        "OutputS3Region": "us-east-1",
        "Parameters": {
          "string": [
            {
              "workingDirectory": [
                ""
              ],
              "executionTimeout": [
                "3600"
              ],
              "commands": [
                "sudo systemctl restart solserver"
              ]
            }
          ]
        },
        "ServiceRoleArn": "${aws_iam_role.state.arn}",
        "Targets": [
          {
            "Key": "InstanceIds",
            "Values": [
              "${aws_instance.rhel1.id}"
            ]
          }
        ],
        "TimeoutSeconds": 3600
      },
      "Resource": "arn:aws:states:::aws-sdk:ssm:sendCommand",
      "End": true
    }
  }
}
EOF
}
# resource "aws_launch_template" "wintemp" {
#   name_prefix   = "wintemp"
#   image_id      = var.ami
#   instance_type = var.instance_type
#   key_name = "dn"
# }
# resource "aws_autoscaling_group" "winapp" {
#   availability_zones = ["${var.region}a"]
#   desired_capacity   = 2
#   max_size           = 2
#   min_size           = 1

#   launch_template {
#     id      = "${aws_launch_template.wintemp.id}"
#     version = "$Latest"
#   }
# }