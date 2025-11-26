output "bastion_ip" {
  value = aws_instance.bastion.public_ip
  description = "Public IP of the Bastion Host"
}

output "target_private_ip" {
  value = aws_instance.target.private_ip
  description = "Private IP of the Target (Internal only)"
}

output "target_instance_id" {
  value = aws_instance.target.id
  description = "Instance ID of the Target (You will need this for the exploit)"
}

output "ssh_command" {
  value = "ssh -i ctf_key.pem ubuntu@${aws_instance.bastion.public_ip}"
  description = "Command to connect to the bastion"
}