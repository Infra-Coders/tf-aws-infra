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

variable "spot_options" {
  type = object({
    max_price = string
  })
  default = {
    max_price = null
  }
}
