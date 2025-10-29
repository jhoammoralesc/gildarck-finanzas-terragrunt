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
  name         = "gildarck-upload-handler-v2"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = "${local.name}-dev"
  description    = "Upload Handler v2.0 - Google Photos style batch upload system"
  handler        = "lambda_function.lambda_handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  timeout        = 900
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
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:PutObjectAcl",
        "s3:GeneratePresignedUrl"
      ]
      resources = [
        "arn:aws:s3:::gildarck-media-dev",
        "arn:aws:s3:::gildarck-media-dev/*"
      ]
    }
    dynamodb_access = {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      resources = [
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-batch-uploads-dev",
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev",
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-media-metadata-dev/index/*"
      ]
    }
    sqs_access = {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:GetQueueAttributes"
      ]
      resources = [
        "arn:aws:sqs:us-east-1:496860676881:gildarck-batch-queue-dev",
        "arn:aws:sqs:us-east-1:496860676881:gildarck-batch-queue-dev-dlq"
      ]
    }
  }
  
  allowed_triggers = {
    APIGateway = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:us-east-1:496860676881:*/*/*"
    }
  }
  
  environment_variables = {
    BUCKET_NAME = "gildarck-media-dev"
    BATCH_TABLE_NAME = "gildarck-batch-uploads-dev"
    SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-batch-queue-dev"
    DEDUPLICATION_TABLE = "gildarck-media-metadata-dev"
    MAX_PARALLEL_STREAMS = "10"
    BATCH_THRESHOLD = "10"
    CHUNK_SIZE = "50"
  }

  tags = merge(local.tags, {
    Component = "upload-handler-v2"
    Version = "2.0"
    Features = "batch-upload-intelligent-routing"
  })
}
