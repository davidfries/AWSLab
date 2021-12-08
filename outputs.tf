output "instance_id" {
  description = "ID of the EC2 instance"
  value       = [aws_instance.app_server.id,
  aws_instance.app_server2.id]
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = [aws_instance.app_server.public_ip,
  aws_instance.app_server2.public_ip]
}
output "Administrator_Password" {
    value = ["${rsadecrypt(aws_instance.app_server.password_data, file("dn.pem"))}","${rsadecrypt(aws_instance.app_server2.password_data, file("dn.pem"))}"]
}
