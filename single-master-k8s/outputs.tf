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

output "worker_private_dns" {
  value = {
    for w in local.workers[var.workers_kind] : w => aws_instance.k8s-worker[w].private_dns
  }
}

# Prefix with zz_ so it prints at the bottom of terraform output.
output "zz_next_step_bootstrap" {
  description = "Reminder to bootstrap the cluster after infrastructure is ready"
  value       = "Next: run ./scripts/BOOTSTRAP_KUBE.sh from single-master-k8s/"
}
