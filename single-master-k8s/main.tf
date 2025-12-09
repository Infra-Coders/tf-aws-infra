
resource "aws_key_pair" "ic-k8slab" {
  key_name   = "ic-k8slab"
  public_key = file("${path.module}/ssh/ic-k8slab.pub")
}

resource "aws_ec2_instance_metadata_defaults" "enforce-imdsv2" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 3
}

resource "aws_iam_role" "ic-aws-ebs-csi-role-ec2" {
  name = "ic-aws-ebs-csi-role-ec2"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "ic-aws-ebs-csi-role-ec2" {
  role       = aws_iam_role.ic-aws-ebs-csi-role-ec2.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_instance_profile" "ic-aws-ebs-csi-ec2" {
  name = "ic-aws-ebs-csi-ec2"
  role = aws_iam_role.ic-aws-ebs-csi-role-ec2.name
}

resource "aws_instance" "k8s-master" {
  ami      = data.aws_ami.ubuntu.id
  for_each = toset(local.masters[var.masters_kind])

  # bind role
  iam_instance_profile = aws_iam_instance_profile.ic-aws-ebs-csi-ec2.name
  instance_type = local.instance_type[var.masters_kind]

  subnet_id                   = aws_subnet.ic-k8slab-1a.id
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = local.cloud_init_user_data_base64
  key_name                    = aws_key_pair.ic-k8slab.key_name

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

  dynamic "instance_market_options" {
    for_each = var.masters_spot_enabled ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.spot_options.max_price
      }
    }
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
  # bind role
  iam_instance_profile = aws_iam_instance_profile.ic-aws-ebs-csi-ec2.name

  subnet_id                   = aws_subnet.ic-k8slab-1a.id
  vpc_security_group_ids      = [aws_security_group.ic-k8slab-sg.id]
  associate_public_ip_address = true
  user_data_base64            = local.cloud_init_user_data_base64
  key_name                    = aws_key_pair.ic-k8slab.key_name

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

  dynamic "instance_market_options" {
    for_each = var.workers_spot_enabled ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.spot_options.max_price
      }
    }
  }

  depends_on = [
    aws_subnet.ic-k8slab-1a,
    aws_internet_gateway.ic-k8slab-igw,
    aws_route.ic-k8slab-route,
  ]
}
