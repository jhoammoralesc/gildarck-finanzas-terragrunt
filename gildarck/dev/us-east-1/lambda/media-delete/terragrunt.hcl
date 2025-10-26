terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/lambda/function.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "gildarck-media-delete"
  service_vars = read_terragrunt_config("service.hcl")
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = "${local.name}"
  description    = "Google Photos-style media delete handler (trash/restore/permanent/list)"
  handler        = "index.lambda_handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  timeout        = 60
  memory_size    = 512
  create_package = false
  publish        = true

  local_existing_package = "lambda.zip"
  
  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject", 
        "s3:DeleteObject",
        "s3:CopyObject",
        "s3:GetObjectMetadata",
        "s3:PutObjectMetadata"
      ]
      resources = ["arn:aws:s3:::gildarck-media-dev/*"]
    }
    s3_bucket_access = {
      effect = "Allow"
      actions = [
        "s3:ListBucket"
      ]
      resources = ["arn:aws:s3:::gildarck-media-dev"]
    }
    dynamodb_access = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      resources = [
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev",
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev/index/*"
      ]
    }
  }
  
  environment_variables = {
    BUCKET_NAME = "gildarck-media-dev"
    TABLE_NAME  = "gildarck-media-metadata-dev"
    REGION      = "us-east-1"
  }

  tags = local.tags

  # API Gateway permissions
  allowed_triggers = {
    APIGatewayAny = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:us-east-1:496860676881:gslxbu791e/*/*"
    }
  }
}
