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
  region = "ap-southeast-1"
  default_tags {
    tags = { Project = "fds", ManagedBy = "terraform", Stack = "account" }
  }
}
