include "root" {
  path = find_in_parent_folders()
}

dependency "s3_media" {
  config_path = "../../s3/media-storage"
}

dependency "cognito" {
  config_path = "../../cognito/user-pool"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.environment_vars.locals.environment
}

inputs = {
  # Identity Pool for authenticated users
  identity_pool_name = "gildarck_media_access_${local.environment}"
  
  # Cognito User Pool integration
  cognito_identity_providers = [
    {
      client_id     = dependency.cognito.outputs.cognito_user_pool_client_id
      provider_name = dependency.cognito.outputs.cognito_user_pool_endpoint
    }
  ]
  
  # IAM role for authenticated users with user-specific S3 access
  authenticated_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${dependency.s3_media.outputs.s3_bucket_arn}/$${cognito-identity.amazonaws.com:sub}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = dependency.s3_media.outputs.s3_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = "$${cognito-identity.amazonaws.com:sub}/*"
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = local.environment
    Service     = "iam"
    Name        = "gildarck-s3-user-access-${local.environment}"
  }
}
