provider "aws" {
  region = var.aws_region
  #access_key = <aws_access_key_id>
  #secret_key = <aws_secret_access_key>
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.22"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
