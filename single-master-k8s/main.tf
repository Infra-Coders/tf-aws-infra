
resource "aws_key_pair" "ic-k8slab-cluster" {
  key_name   = "ic-k8slab-cluster"
  public_key = file("${path.module}/ssh/ic-k8slab-cluster.pub")
}

resource "aws_instance" "k8s-master" {
  ami      = data.aws_ami.ubuntu.id
  for_each = toset(local.masters[var.masters_kind])

  instance_type = local.instance_type[var.masters_kind]

  subnet_id                   = aws_subnet.ic-k8slab-1a.id
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = local.cloud_init_user_data_base64
  key_name         = "ic-k8slab-cluster"

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
  key_name         = "ic-k8slab-cluster"

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
