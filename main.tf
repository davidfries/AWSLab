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
  default_tags {
    tags={
      BKP="YES"
      Environment="DEV"
      Provider="Terraform"
    }
  }
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
    BKP="YES"
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
    BKP="YES"
  }
}
resource "aws_instance" "rhel1" {
  ami                    = "ami-0b0af3577fe5e3532"
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.test_profile.name
  vpc_security_group_ids = ["${aws_security_group.allow-rdp.id}", "${aws_security_group.allow-ssh.id}"]
  key_name               = "dn"
  user_data              = file("./script.sh")
  tags = {
    Name = "Linux",
    BKP="YES"
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
          "commands":["sudo systemctl restart solserver"]
        },
        
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
# resource "aws_iam_role" "bkp" {
#   name               = "bkp"
#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": ["sts:AssumeRole"],
#       "Effect": "allow",
#       "Principal": {
#         "Service": ["backup.amazonaws.com"]
#       }
#     }
#   ]
# }
# POLICY
# }

# resource "aws_iam_role_policy_attachment" "bkp" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
#   role       = aws_iam_role.bkp.name
# }

# resource "aws_backup_selection" "bkpsel" {
#   plan_id      = aws_backup_plan.example.id
#   name = "backup"
#   selection_tag {
#     type  = "STRINGEQUALS"
#     key   = "BKP"
#     value = "YES"
#   }
#   iam_role_arn = aws_iam_role.bkp.arn
# }
# resource "aws_backup_vault" "example" {
#   name        = "example_backup_vault"
# }
# resource "aws_backup_plan" "example" {
#   name = "tf_example_backup_plan"

#   rule {
#     rule_name         = "tf_example_backup_rule"
#     target_vault_name = aws_backup_vault.example.name
#     schedule          = "cron(0 0 1 * * ?)"
#   }

#   advanced_backup_setting {
#     backup_options = {
#       WindowsVSS = "enabled"
#     }
#     resource_type = "EC2"
#   }
# }

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