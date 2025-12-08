data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "k8s_nodes_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "k8s_nodes" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:DescribeTable",
    ]
    resources = [aws_dynamodb_table.leader_lock.arn]
  }

  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}*"
    ]
  }

  dynamic "statement" {
    for_each = var.kms_key_id != "" ? [var.kms_key_id] : []
    content {
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [statement.value]
      effect    = "Allow"
    }
  }
}

resource "aws_iam_role" "k8s_nodes" {
  name               = "${var.cluster_name}-nodes"
  assume_role_policy = data.aws_iam_policy_document.k8s_nodes_assume_role.json
}

resource "aws_iam_role_policy" "k8s_nodes" {
  name   = "${var.cluster_name}-nodes"
  role   = aws_iam_role.k8s_nodes.id
  policy = data.aws_iam_policy_document.k8s_nodes.json
}

resource "aws_iam_instance_profile" "k8s_nodes" {
  name = "${var.cluster_name}-nodes"
  role = aws_iam_role.k8s_nodes.name
}
