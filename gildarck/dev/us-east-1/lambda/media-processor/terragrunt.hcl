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
  name         = "gildarck-media-processor"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = "${local.name}"
  description    = "Lambda function for media processing with AI analysis"
  handler        = "index.lambda_handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  timeout        = 300
  memory_size    = 1024
  create_package = false
  publish        = true

  local_existing_package = "lambda.zip"
  
  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = ["arn:aws:s3:::gildarck-media-dev/*"]
    }
    dynamodb_access = {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:Query"
      ]
      resources = [
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev",
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev/index/*"
      ]
    }
    rekognition_access = {
      effect = "Allow"
      actions = [
        "rekognition:DetectFaces",
        "rekognition:DetectLabels"
      ]
      resources = ["*"]
    }
  }
  
  allowed_triggers = {
    S3EventNotification = {
      service  = "events"
      resource = "*"
    }
  }
  
  environment_variables = {
    S3_BUCKET      = "gildarck-media-dev"
    DYNAMODB_TABLE = "gildarck-media-metadata-dev"
    REGION         = "us-east-1"
  }

  tags = local.tags
}
