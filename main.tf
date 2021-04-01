terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "mybuckett117"
    key    = "myaccount/terraform.tfstate"
    region = "eu-north-1"
  }
}


# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
}
# 

# Locals
locals {
  environment = "dev"

  tags = {
    terraform   = "True"
    environment = local.environment
  }
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.main.id
  service_name = "com.amazonaws.eu-north-1.s3"
  #vpc_endpoint_type = "Interface"

}

# Create the Private hosted zone
resource "aws_route53_zone" "private" {
  name = "s3.eu-north-1.amazonaws.com"

  vpc {
    vpc_id = data.aws_vpc.main.id
  }
}

resource "aws_route53_record" "alias" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "s3.eu-north-1.amazonaws.com"
  type    = "A"
  alias {
    name                   = data.aws_vpc_endpoint.s3.dns_entry[0]["dns_name"]
    zone_id                = data.aws_vpc_endpoint.s3.dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = true
  }
}

#Create Inbound resolver endpoint 

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  #count  = length(data.aws_subnet_ids.private.ids)
  #id     = tolist(data.aws_subnet_ids.private.ids)[count.index]
}

resource "aws_security_group" "inbound_endpoint" {
  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow inbound from CDL"
    from_port   = 53
    protocol    = "tcp"
    to_port     = 53
  }

  ingress {
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow inbound from CDL"
    from_port   = 53
    protocol    = "udp"
    to_port     = 53
  }
}

resource "aws_route53_resolver_endpoint" "distcp" {
  name      = "distcp_endpoint"
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.inbound_endpoint.id
  ]

  ip_address {

    subnet_id = element(data.aws_subnet_ids.private.ids[*], 1)

  }

  ip_address {

    subnet_id = element(data.aws_subnet_ids.private.ids[*], 2)

  }

  tags = local.tags
}
