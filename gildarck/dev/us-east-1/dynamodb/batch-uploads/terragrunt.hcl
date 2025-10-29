include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-dynamodb-table.git?ref=v4.0.1"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.environment_vars.locals.environment
  name = "gildarck-batch-uploads-${local.environment}"
}

inputs = {
  name           = local.name
  hash_key       = "batch_id"
  billing_mode   = "PAY_PER_REQUEST"
  
  attributes = [
    {
      name = "batch_id"
      type = "S"
    },
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "master_batch_id"
      type = "S"
    }
  ]
  
  global_secondary_indexes = [
    {
      name            = "UserIndex"
      hash_key        = "user_id"
      projection_type = "ALL"
    },
    {
      name            = "master-batch-index"
      hash_key        = "master_batch_id"
      projection_type = "ALL"
    }
  ]
  
  ttl_enabled = true
  ttl_attribute_name = "ttl"
  
  tags = {
    Environment = local.environment
    Service     = "dynamodb"
    Name        = local.name
  }
}

# Schema:
# {
#   "batch_id": "uuid",
#   "user_id": "uuid",
#   "status": "processing|completed|failed",
#   "total_files": 50,
#   "processed_files": 50,
#   "upload_urls": [
#     {
#       "filename": "file.jpg",
#       "upload_url": "https://...",
#       "s3_key": "user_id/originals/2025/10/file.jpg"
#     }
#   ],
#   "created_at": "2025-10-27T20:00:00Z",
#   "updated_at": "2025-10-27T20:01:00Z",
#   "ttl": 1730073600  // 24 hours expiration
# }
