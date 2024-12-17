# outputs.tf

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ubuntu_box.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.ubuntu_box.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.ubuntu_box.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = data.aws_subnet.selected.id
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.ubuntu_box.public_ip}"
}

output "ssm_command" {
  description = "Command to connect via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.ubuntu_box.id} --region ${var.region}"
}