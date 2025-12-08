locals {
  cloud_init_common_vars = {
    k8sadmin_ssh_key     = trimspace(tls_private_key.ic-k8slab-cluster.public_key_openssh)
    pod_cidr             = var.pod_cidr
    service_cidr         = var.service_cidr
    kube_version         = var.kube_version
    cluster_name         = var.cluster_name
    dynamodb_lock_table  = local.dynamodb_lock_table
    ssm_parameter_prefix = var.ssm_parameter_prefix
    kms_key_id           = var.kms_key_id
    lock_ttl_seconds     = var.lock_ttl_seconds
    aws_region           = var.aws_region
  }

  ssh_key_name = "${var.cluster_name}-${substr(sha1(tls_private_key.ic-k8slab-cluster.public_key_openssh), 0, 8)}"

  control_plane_names = [
    for i in range(var.control_plane_count) : "${var.cluster_name}-cp-${i + 1}"
  ]

  worker_names = [
    for i in range(var.worker_count) : "${var.cluster_name}-worker-${i + 1}"
  ]

  control_plane_ami = var.control_plane_ami_id != "" ? var.control_plane_ami_id : data.aws_ami.ubuntu.id
  worker_ami        = var.worker_ami_id != "" ? var.worker_ami_id : data.aws_ami.ubuntu.id

  dynamodb_lock_table = var.dynamodb_lock_table_name != "" ? var.dynamodb_lock_table_name : "${var.cluster_name}-leader-lock"

  subnet_ids = [
    aws_subnet.ic-k8slab-1a.id,
    aws_subnet.ic-k8slab-1b.id,
    aws_subnet.ic-k8slab-1c.id,
  ]
}
