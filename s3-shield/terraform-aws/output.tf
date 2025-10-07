output "instance_public_ip_addr" {
  value = aws_instance.tf_ve6.public_ip
}

output "instance_private_ip_addr" {
  value = aws_instance.tf_ve6.private_ip
}
