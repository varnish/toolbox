output "instance_public_ip_addr" {
  value = aws_instance.tf-ve6.public_ip
}

output "instance_private_ip_addr" {
  value = aws_instance.tf-ve6.private_ip
}
