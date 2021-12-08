variable "ami" {
  description = "Value of the AMI for the EC2 instance"
  type        = string
  default     = "ami-0b17e49efb8d755c3"
}
variable "instance_type" {
  description = "Value of the type for the EC2 instance"
  type        = string
  default     = "t3.medium"
}
variable "name" {
  description = "Value of the name for the EC2 instance"
  type        = string
  default     = "winserver"
}
variable "ip" {
  description = "Value of the name for client public IP"
  type        = string
  default     = "97.118.135.238/32"
}
variable "PATH_TO_PRIVATE_KEY" { default = "C:\\Users\\DJ\\Downloads\\dn.pem" }
variable "PATH_TO_PUBLIC_KEY" { default = "mykey.pub" }
variable "bucketname" {default = "djf-logging-bucket"}
variable "region" {
  default="us-east-1"
}