terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0, < 3.0.0"
    }
  }
}
