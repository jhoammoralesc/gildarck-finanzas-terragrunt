include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v4.1.2"
}

locals {
  name = "gildarck-media-${local.environment}"
}

inputs = {
  bucket = local.name
  
  versioning = {
    enabled = true
  }
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  lifecycle_configuration = {
    rule = [
      {
        id     = "trash_cleanup"
        status = "Enabled"
        filter = {
          prefix = "*/media/trash/"
        }
        expiration = {
          days = 30
        }
      }
    ]
  }
  
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "PUT", "POST", "DELETE"]
      allowed_origins = [
        "https://develop.d1voxl70yl4svu.amplifyapp.com",
        "http://localhost:3000"
      ]
      max_age_seconds = 3000
    }
  ]
  
  tags = {
    Environment = local.environment
    Service     = "s3"
    Name        = local.name
  }
}
