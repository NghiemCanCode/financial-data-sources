terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "fds", ManagedBy = "terraform", "fds:source" = "core-banking" }
  }
}

data "aws_caller_identity" "me" {}

data "aws_region" "this" {}