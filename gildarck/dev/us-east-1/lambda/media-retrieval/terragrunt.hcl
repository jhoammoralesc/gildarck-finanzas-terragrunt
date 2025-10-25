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
  name         = "gildarck-media-retrieval"
  service_vars = read_terragrunt_config("service.hcl")
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = "${local.name}"
  description    = "Lambda function for media retrieval and thumbnail serving"
  handler        = "index.lambda_handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  timeout        = 30
  memory_size    = 256
  create_package = false
  publish        = true

  local_existing_package = "lambda.zip"
  
  attach_policy_statements = true
  policy_statements = {
    dynamodb_access = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:Query"
      ]
      resources = [
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev",
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev/index/*"
      ]
    }
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = ["arn:aws:s3:::gildarck-media-dev/*"]
    }
  }
  
  environment_variables = {
    DYNAMODB_TABLE = "gildarck-media-metadata-dev"
    S3_BUCKET      = "gildarck-media-dev"
    REGION         = "us-east-1"
  }

  tags = local.tags
}
