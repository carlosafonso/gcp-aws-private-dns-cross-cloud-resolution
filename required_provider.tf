terraform {
  required_version = "~> 1.6"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    google = {
      source  = "hashicorp/google",
      version = "~> 6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.49"
    }
  }
}
