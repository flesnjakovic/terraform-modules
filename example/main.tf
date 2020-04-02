locals {
  bucket_name             = "${random_id.bucket_prefix.dec}-s3-bucket"
  destination_bucket_name = "${random_id.bucket_prefix.dec}-s3-bucket-replica"
  origin_region           = "eu-west-1"
  replica_region          = "eu-central-1"
}

provider "aws" {
  version = "~> 2.55.0"
  region  = local.origin_region
}

provider "aws" {
  version = "~> 2.55.0"
  region  = local.replica_region
  alias   = "replica"
}

data "aws_caller_identity" "user" {}

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "aws_kms_key" "k" {
}

resource "aws_kms_key" "replica" {
  provider    = "aws.replica"
  description = "S3 bucket replication KMS key"
}

module "replica_bucket" {
  source = "../"

  providers = {
    aws = "aws.replica"
  }

  bucket = local.destination_bucket_name
  region = local.replica_region
  acl    = "private"

  versioning = {
    enabled = true
  }
}

module "log_bucket" {
  source = "../"

  bucket = "logs-${local.bucket_name}"
  acl    = "log-delivery-write"
}

module "s3_bucket" {
  source = "../"

  bucket = local.bucket_name

  tags = {
    Environment = "PROD"
  }

  logging = {
    target_bucket = module.log_bucket.s3_bucket_id
    target_prefix = "log/"
  }

  versioning = {
    enabled = true
  }

  create_bucket_rw_user = true

  lifecycle_rule = [
    {
      id      = "log"
      enabled = true
      prefix  = "log/"

      tags = {
        rule      = "log"
        autoclean = "true"
      }

      transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA"
          }, {
          days          = 60
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = 75
      }

      noncurrent_version_expiration = {
        days = 30
      }
    }
  ]

  replication_configuration = {
    rules = [
      {
        id       = "logs"
        status   = "Enabled"
        priority = 10

        source_selection_criteria = {
          sse_kms_encrypted_objects = {
            enabled = true
          }
        }

        filter = {
          prefix = "logs"
          tags = {
            Replication = "On"
          }
        }

        destination = {
          bucket             = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class      = "STANDARD"
          replica_kms_key_id = aws_kms_key.replica.arn
          account_id         = data.aws_caller_identity.user.account_id
          access_control_translation = {
            owner = "Destination"
          }
        }
      }
    ]
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.k.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}