locals {
  default_num_ha_vpn_interfaces = 2
}

data "aws_availability_zones" "available" {
  state  = "available"
  region = local.aws_region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name_prefix
  cidr = local.aws_vpc_ip_range

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = cidrsubnets(local.aws_vpc_private_subnet_base_ip_range, 2, 2, 2)
  public_subnets  = cidrsubnets(local.aws_vpc_public_subnet_base_ip_range, 2, 2, 2)

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

resource "aws_security_group" "allow_all" {
  name        = "${local.name_prefix}-allow-all"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name      = "${local.name_prefix}-inbound-resolver"
  direction = "INBOUND"
  security_group_ids = [
    aws_security_group.allow_all.id
  ]

  ip_address {
    subnet_id = module.vpc.private_subnets[0]
  }

  ip_address {
    subnet_id = module.vpc.private_subnets[1]
  }

  ip_address {
    subnet_id = module.vpc.private_subnets[2]
  }
}

resource "aws_route53_zone" "private" {
  name = "example.foobar"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "www.example.foobar"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.web_server.private_ip]
}

resource "aws_customer_gateway" "gwy" {
  count = local.default_num_ha_vpn_interfaces

  device_name = "${local.name_prefix}-gwy-${count.index}"
  bgp_asn     = local.gcp_router_asn
  type        = "ipsec.1"
  ip_address  = google_compute_ha_vpn_gateway.gwy.vpn_interfaces[count.index]["ip_address"]
}

resource "aws_ec2_transit_gateway" "tgw" {
  amazon_side_asn                 = local.aws_router_asn
  description                     = "EC2 transit gateway"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  vpn_ecmp_support                = "enable"
  dns_support                     = "enable"

  tags = {
    Name = "${local.name_prefix}-tgw"
  }
}

resource "aws_route" "private_to_gcp" {
  for_each = toset(module.vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = local.gcp_subnet_ip_range
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "public_to_gcp" {
  for_each = toset(module.vpc.public_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = local.gcp_subnet_ip_range
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "private_to_gcp_custom" {
  for_each = toset(module.vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "35.199.192.0/19"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "public_to_gcp_custom" {
  for_each = toset(module.vpc.public_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = "35.199.192.0/19"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "awscc_ec2_transit_gateway_attachment" "tgw_attachment" {
  subnet_ids         = module.vpc.private_subnets
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc.vpc_id

  tags = [
    {
      key   = "Name"
      value = "${local.name_prefix}-tgw-attachment"
    }
  ]
}

resource "aws_vpn_connection" "vpn_conn" {
  count = var.num_tunnels / 2

  customer_gateway_id   = aws_customer_gateway.gwy[count.index % 2].id
  type                  = "ipsec.1"
  transit_gateway_id    = aws_ec2_transit_gateway.tgw.id
  tunnel1_preshared_key = var.shared_secret
  tunnel2_preshared_key = var.shared_secret

  tags = {
    Name = "${local.name_prefix}-vpn-connn"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.allow_all.id]
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              EC2_AVAIL_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
              EC2_REGION=$(echo "$EC2_AVAIL_ZONE" | sed 's/[a-z]$//')
              EC2_PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
              EC2_INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              echo "{\"region\": \"$EC2_REGION\", \"availability_zone\": \"$EC2_AVAIL_ZONE\", \"private_ip\": \"$EC2_PRIVATE_IP\", \"instance_id\": \"$EC2_INSTANCE_ID\"}" > /var/www/html/index.html
              EOF

  tags = {
    Name = "${local.name_prefix}-web-server"
  }
}
