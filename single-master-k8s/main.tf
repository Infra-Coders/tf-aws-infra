
resource "tls_private_key" "ic-k8slab-cluster" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ic-k8slab-cluster" {
  key_name   = local.ssh_key_name
  public_key = tls_private_key.ic-k8slab-cluster.public_key_openssh

  lifecycle {
    create_before_destroy = true
  }
}

resource "local_sensitive_file" "ssh_private_key" {
  filename             = "${path.module}/ssh/ic-k8slab-cluster.pem"
  content              = tls_private_key.ic-k8slab-cluster.private_key_pem
  file_permission      = "0600"
  directory_permission = "0700"
}

resource "local_file" "ssh_public_key" {
  filename             = "${path.module}/ssh/ic-k8slab-cluster.pub"
  content              = trimspace(tls_private_key.ic-k8slab-cluster.public_key_openssh)
  file_permission      = "0644"
  directory_permission = "0700"
}

resource "aws_instance" "k8s_master" {
  count = var.control_plane_count

  ami           = local.control_plane_ami
  instance_type = var.control_plane_instance_type

  subnet_id                   = element(local.subnet_ids, count.index % length(local.subnet_ids))
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = base64encode(templatefile("${path.module}/cloud-init/control-plane.yaml", merge(local.cloud_init_common_vars, { node_role = "control-plane" })))
  key_name                    = aws_key_pair.ic-k8slab-cluster.key_name
  iam_instance_profile        = aws_iam_instance_profile.k8s_nodes.name

  tags = {
    Name    = local.control_plane_names[count.index]
    Role    = "control-plane"
    Cluster = var.cluster_name
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "optional"
    http_endpoint = "enabled"
  }

  depends_on = [
    aws_subnet.ic-k8slab-1a,
    aws_internet_gateway.ic-k8slab-igw,
    aws_route.ic-k8slab-route,
    aws_dynamodb_table.leader_lock,
  ]
  user_data_replace_on_change = true
}

resource "aws_instance" "k8s_worker" {
  count = var.worker_count

  ami           = local.worker_ami
  instance_type = var.worker_instance_type

  subnet_id                   = element(local.subnet_ids, count.index % length(local.subnet_ids))
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = base64encode(templatefile("${path.module}/cloud-init/worker.yaml", merge(local.cloud_init_common_vars, { node_role = "worker" })))
  key_name                    = aws_key_pair.ic-k8slab-cluster.key_name
  iam_instance_profile        = aws_iam_instance_profile.k8s_nodes.name

  tags = {
    Name    = local.worker_names[count.index]
    Role    = "worker"
    Cluster = var.cluster_name
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "optional"
    http_endpoint = "enabled"
  }

  depends_on = [
    aws_subnet.ic-k8slab-1a,
    aws_internet_gateway.ic-k8slab-igw,
    aws_route.ic-k8slab-route,
    aws_dynamodb_table.leader_lock,
  ]
  user_data_replace_on_change = true
}

# Pre-create SSM parameters so they are managed/destroyed with Terraform.
resource "aws_ssm_parameter" "control_plane_join" {
  name  = "${var.ssm_parameter_prefix}/control-plane-join"
  type  = "SecureString"
  value = "pending"
  key_id = var.kms_key_id != "" ? var.kms_key_id : null

  tags = {
    Name    = "${var.cluster_name}-control-plane-join"
    Cluster = var.cluster_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "worker_join" {
  name  = "${var.ssm_parameter_prefix}/worker-join"
  type  = "SecureString"
  value = "pending"
  key_id = var.kms_key_id != "" ? var.kms_key_id : null

  tags = {
    Name    = "${var.cluster_name}-worker-join"
    Cluster = var.cluster_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "control_plane_endpoint" {
  name  = "${var.ssm_parameter_prefix}/control-plane-endpoint"
  type  = "SecureString"
  value = "pending"
  key_id = var.kms_key_id != "" ? var.kms_key_id : null

  tags = {
    Name    = "${var.cluster_name}-control-plane-endpoint"
    Cluster = var.cluster_name
  }

  lifecycle {
    ignore_changes = [value]
  }
}
