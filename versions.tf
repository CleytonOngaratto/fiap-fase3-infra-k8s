terraform {
  # >= 1.11: `use_lockfile` (lock nativo do S3) é GA a partir daqui, o que dispensa DynamoDB.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Config parcial: o bucket depende da conta do lab.
  # terraform init "-backend-config=backend.hcl"  (gerado por scripts/bootstrap-backend.ps1)
  backend "s3" {}
}
