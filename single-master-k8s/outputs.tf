#output "aws_ami" {
#  description = "AMI Ubuntu"
#  value= data.aws_ami.ubuntu
#}

#output "aws_vpc" {
#  description = "VPC"
#  value = data.aws_vpc.k8s_lab
#}

#output "aws_subnet" {
#  description = "Subnet"
#  value = data.aws_subnet.k8s_lab
#}

#output "aws_security_group" {
#  description = "Security Group"
#  value = data.aws_security_group.k8s_lab
#}

output "master_public_ip" {
  value = {
    for idx, inst in aws_instance.k8s_master : inst.tags.Name => inst.public_ip
  }
}

output "master_private_dns" {
  value = {
    for _, inst in aws_instance.k8s_master : inst.tags.Name => inst.private_dns
  }
}

output "worker_public_ip" {
  value = {
    for _, inst in aws_instance.k8s_worker : inst.tags.Name => inst.public_ip
  }
}

output "worker_private_dns" {
  value = {
    for _, inst in aws_instance.k8s_worker : inst.tags.Name => inst.private_dns
  }
}
