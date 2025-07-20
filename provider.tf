provider "random" {}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}
