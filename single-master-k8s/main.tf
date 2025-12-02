
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

resource "aws_ec2_instance_metadata_defaults" "enforce-imdsv2" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 3
}

resource "aws_instance" "k8s-master" {
  ami      = data.aws_ami.ubuntu.id
  for_each = toset(local.masters[var.masters_kind])

  instance_type = local.instance_type[var.masters_kind]

  subnet_id                   = aws_subnet.ic-k8slab-1a.id
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = local.cloud_init_user_data_base64
  key_name                    = aws_key_pair.ic-k8slab-cluster.key_name

  tags = {
    Name = each.value
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
  ]
}

resource "aws_instance" "k8s-worker" {
  ami = data.aws_ami.ubuntu.id

  for_each = toset(local.workers[var.workers_kind])

  subnet_id                   = aws_subnet.ic-k8slab-1a.id
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = local.cloud_init_user_data_base64
  key_name                    = aws_key_pair.ic-k8slab-cluster.key_name

  tags = {
    Name = each.value
  }

  instance_type = local.instance_type[var.workers_kind]

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
  ]
}
