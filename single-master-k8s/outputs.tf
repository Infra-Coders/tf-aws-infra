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
    for m in local.masters[var.masters_kind] : m => aws_instance.k8s-master[m].public_ip
  }
}

output "master_public_ip_to_host" {
  value = {
    for m in local.masters[var.masters_kind] : aws_instance.k8s-master[m].public_ip => m
  }
}

output "master_private_dns" {
  value = {
    for w in local.masters[var.masters_kind] : w => aws_instance.k8s-master[w].private_dns
  }
}

output "worker_public_ip" {
  value = {
    for w in local.workers[var.workers_kind] : w => aws_instance.k8s-worker[w].public_ip
  }
}

output "worker_public_ip_to_host" {
  value = {
    for w in local.workers[var.workers_kind] : aws_instance.k8s-worker[w].public_ip => w
  }
}

output "worker_private_dns" {
  value = {
    for w in local.workers[var.workers_kind] : w => aws_instance.k8s-worker[w].private_dns
  }
}
