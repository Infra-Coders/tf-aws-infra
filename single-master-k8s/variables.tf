variable "region" {
  default = "eu-central-1"
  type    = string
}

variable "aws_profile" {
  type    = string
}

variable "workers_kind" {
  default = "workers3"
}

variable "masters_kind" {
  default = "masters1"
}

variable "workers_spot_enabled" {
  type    = bool
  default = true
}

variable "masters_spot_enabled" {
  type    = bool
  default = false
}

variable "instance_type" {
  type    = string
  default = "free"
}

variable "spot_options" {
  type = object({
    max_price = string
  })
  default = {
    max_price = null
  }
}
