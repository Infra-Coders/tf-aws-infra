# IAM AWS Policies

# Control Plane IAM Policy
resource "aws_iam_policy" "aws_cloud_provider_cp" {
  name        = "ic-k8s-aws-cloud-provider-cp-policy"
  description = "IAM policy for Kubernetes CP nodes with AWS Cloud Provider"
  policy      = file("${path.module}/iam_policies/aws_cloud_controller_manager_CP_policy.json")

}

# Data Plane (Worker) IAM Policy
resource "aws_iam_policy" "aws_cloud_provider_dp" {
  name        = "ic-k8s-aws-cloud-provider-dp-policy"
  description = "IAM policy for Kubernetes DP nodes with AWS Cloud Provider"
  policy      = file("${path.module}/iam_policies/aws_cloud_controller_manager_DP_policy.json")

}

# AWS ALB IAM Policy
resource "aws_iam_policy" "aws_alb" {
  name        = "ic-k8s-aws-alb-policy"
  description = "IAM policy for Kubernetes & AWS ALB"
  policy      = file("${path.module}/iam_policies/aws_LB_policy.json")

}

# Route 53 Policy for external-dns
resource "aws_iam_policy" "aws_external_dns" {
  name        = "ic-k8s-aws-external-dns-policy"
  description = "IAM policy for external-dns to manage Route 53 records"
  policy      = file("${path.module}/iam_policies/aws_external_dns_policy.json")

}

# Control Plane IAM Role
resource "aws_iam_role" "k8s_control_plane" {
  name = "ic-k8s-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Worker IAM Role
resource "aws_iam_role" "k8s_data_plane" {
  name = "ic-k8s-data-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ---> CONTROL PLANE

# AWS Cloud Provider for CP
resource "aws_iam_role_policy_attachment" "cp_aws_cloud_provider" {
  role       = aws_iam_role.k8s_control_plane.name
  policy_arn = aws_iam_policy.aws_cloud_provider_cp.arn
}

# AWS ALB for CP (required if aws-load-balancer-controller runs on control-plane)
resource "aws_iam_role_policy_attachment" "cp_aws_alb" {
  role       = aws_iam_role.k8s_control_plane.name
  policy_arn = aws_iam_policy.aws_alb.arn
}

# Attach CSI policies to Control Plane Role (existing CSI driver support)
resource "aws_iam_role_policy_attachment" "cp_aws_ebs_csi" {
  role       = aws_iam_role.k8s_control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "cp_aws_efs_csi" {
  role       = aws_iam_role.k8s_control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# ---> DATA PLANE
# AWS Cloud Provider for DP
resource "aws_iam_role_policy_attachment" "dp_aws_cloud_provider" {
  role       = aws_iam_role.k8s_data_plane.name
  policy_arn = aws_iam_policy.aws_cloud_provider_dp.arn
}

# AWS ALB for DP
resource "aws_iam_role_policy_attachment" "dp_aws_alb" {
  role       = aws_iam_role.k8s_data_plane.name
  policy_arn = aws_iam_policy.aws_alb.arn
}

# AWS Ext DNS for DP
resource "aws_iam_role_policy_attachment" "dp_external_dns" {
  role       = aws_iam_role.k8s_data_plane.name
  policy_arn = aws_iam_policy.aws_external_dns.arn
}

# Attach CSI policies to Worker Role (existing CSI driver support)
resource "aws_iam_role_policy_attachment" "dp_aws_ebs_csi" {
  role       = aws_iam_role.k8s_data_plane.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "dp_aws_efs_csi" {
  role       = aws_iam_role.k8s_data_plane.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# Instance Profiles
resource "aws_iam_instance_profile" "k8s_control_plane_profile" {
  name = "ic-k8s-control-plane-profile"
  role = aws_iam_role.k8s_control_plane.name
}

resource "aws_iam_instance_profile" "k8s_data_plane_profile" {
  name = "ic-k8s-worker-profile"
  role = aws_iam_role.k8s_data_plane.name
}
