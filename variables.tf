variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-east4"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "shared_secret" {
  type = string
}

variable "num_tunnels" {
  type = number
  default = 4
  validation {
    condition     = var.num_tunnels % 2 == 0
    error_message = "number of tunnels needs to be in multiples of 2."
  }
  validation {
    condition     = var.num_tunnels >= 4
    error_message = "min 4 tunnels required for high availability."
  }
  description = <<EOF
    Total number of VPN tunnels. This needs to be in multiples of 2.
  EOF
}
