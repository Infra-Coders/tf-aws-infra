resource "aws_dynamodb_table" "leader_lock" {
  name         = local.dynamodb_lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  tags = {
    Name    = local.dynamodb_lock_table
    Cluster = var.cluster_name
  }
}
