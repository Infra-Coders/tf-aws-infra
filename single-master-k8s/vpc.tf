resource "aws_vpc" "ic-k8slab" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name                                      = "ic-k8slab"
    "kubernetes.io/cluster/ic-k8slab"         = "owned"
  }
}

resource "aws_subnet" "ic-k8slab-1a" {
  vpc_id            = aws_vpc.ic-k8slab.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "eu-central-1a"
  tags = {
    Name                                      = "ic-k8slab-1a"
    "kubernetes.io/cluster/ic-k8slab"         = "owned"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

resource "aws_subnet" "ic-k8slab-1b" {
  vpc_id            = aws_vpc.ic-k8slab.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "eu-central-1b"
  tags = {
    Name                                      = "ic-k8slab-1b"
    "kubernetes.io/cluster/ic-k8slab"         = "owned"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

resource "aws_subnet" "ic-k8slab-1c" {
  vpc_id            = aws_vpc.ic-k8slab.id
  cidr_block        = "10.0.32.0/20"
  availability_zone = "eu-central-1c"
  tags = {
    Name                                      = "ic-k8slab-1c"
    "kubernetes.io/cluster/ic-k8slab"         = "owned"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

resource "aws_internet_gateway" "ic-k8slab-igw" {
  vpc_id = aws_vpc.ic-k8slab.id
  tags = {
    Name = "ic-k8slab-igw"
  }
}

resource "aws_route_table" "ic-k8slab-route-table" {
  vpc_id = aws_vpc.ic-k8slab.id
  tags = {
    Name = "ic-k8slab-route-table"
  }
}

resource "aws_route" "ic-k8slab-route" {
  route_table_id         = aws_route_table.ic-k8slab-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ic-k8slab-igw.id
}

resource "aws_route_table_association" "ic-k8slab-1a-association" {
  subnet_id      = aws_subnet.ic-k8slab-1a.id
  route_table_id = aws_route_table.ic-k8slab-route-table.id
}

resource "aws_route_table_association" "ic-k8slab-1b-association" {
  subnet_id      = aws_subnet.ic-k8slab-1b.id
  route_table_id = aws_route_table.ic-k8slab-route-table.id
}

resource "aws_route_table_association" "ic-k8slab-1c-association" {
  subnet_id      = aws_subnet.ic-k8slab-1c.id
  route_table_id = aws_route_table.ic-k8slab-route-table.id
}

resource "aws_security_group" "ic-k8slab-sg" {
  vpc_id = aws_vpc.ic-k8slab.id
  name   = "ic-k8slab"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.ic-k8slab-1a.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ic-k8slab"
  }
}


