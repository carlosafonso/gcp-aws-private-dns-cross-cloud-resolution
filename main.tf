resource "random_id" "random" {
  byte_length = 2
}

locals {
  gcp_region          = var.gcp_region
  gcp_subnet_ip_range = "192.168.0.0/18"

  aws_region                           = var.aws_region
  aws_vpc_ip_range                     = "10.0.0.0/16"
  aws_vpc_private_subnet_base_ip_range = cidrsubnets(local.aws_vpc_ip_range, 2, 2)[0]
  aws_vpc_public_subnet_base_ip_range  = cidrsubnets(local.aws_vpc_ip_range, 2, 2)[1]

  gcp_router_asn = 65000
  aws_router_asn = 64512

  name_prefix = "gcp-aws-${random_id.random.hex}"
}
