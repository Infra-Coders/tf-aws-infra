variable "cluster_name" {
  description = "Name prefix for all Kubernetes resources."
  type        = string
  default     = "ic-k8slab"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-central-1"
}

variable "control_plane_count" {
  description = "Number of control plane nodes to launch."
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes to launch."
  type        = number
  default     = 1
}

variable "control_plane_instance_type" {
  description = "Instance type for control plane nodes."
  type        = string
  default     = "t3.small"
}

variable "worker_instance_type" {
  description = "Instance type for worker nodes."
  type        = string
  default     = "t3.small"
}

variable "control_plane_ami_id" {
  description = "Override AMI ID for control plane nodes. Leave empty to use the latest filtered Ubuntu image."
  type        = string
  default     = ""
}

variable "worker_ami_id" {
  description = "Override AMI ID for worker nodes. Leave empty to use the latest filtered Ubuntu image."
  type        = string
  default     = ""
}

variable "kube_version" {
  description = "Kubernetes minor version (e.g., 1.32) used for kubeadm/kubelet/kubectl and CRI-O."
  type        = string
  default     = "1.32"
}

variable "pod_cidr" {
  description = "Pod CIDR for Calico."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service CIDR for kubeadm ClusterConfiguration."
  type        = string
  default     = "10.96.0.0/12"
}

variable "dynamodb_lock_table_name" {
  description = "DynamoDB table name for leader election lock. If empty a name will be derived from cluster_name."
  type        = string
  default     = ""
}

variable "ssm_parameter_prefix" {
  description = "Parameter Store prefix for publishing join commands."
  type        = string
  default     = "/k8s/leader"
}

variable "kms_key_id" {
  description = "Optional KMS key ID/ARN for encrypting SSM parameters."
  type        = string
  default     = ""
}

variable "lock_ttl_seconds" {
  description = "TTL for the DynamoDB lock item."
  type        = number
  default     = 900
}
