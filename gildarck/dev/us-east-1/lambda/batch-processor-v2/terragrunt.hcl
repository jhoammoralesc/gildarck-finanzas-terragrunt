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
  name         = "gildarck-batch-processor-v2"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = "${local.name}-dev"
  description    = "Batch Processor v2.0 - Processes SQS messages for batch upload URL generation"
  handler        = "lambda_function.lambda_handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  timeout        = 900
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
        "s3:GetObjectVersion",
        "s3:PutObjectAcl"
      ]
      resources = ["arn:aws:s3:::gildarck-media-dev/*"]
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
        "arn:aws:dynamodb:us-east-1:496860676881:table/gildarck-batch-uploads-dev"
      ]
    }
    sqs_access = {
      effect = "Allow"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      resources = [
        "arn:aws:sqs:us-east-1:496860676881:gildarck-batch-queue-dev",
        "arn:aws:sqs:us-east-1:496860676881:gildarck-batch-queue-dev-dlq"
      ]
    }
  }
  
  event_source_mapping = {
    sqs = {
      event_source_arn = "arn:aws:sqs:us-east-1:496860676881:gildarck-batch-queue-dev"
      batch_size = 1
      maximum_batching_window_in_seconds = 5
    }
  }
  
  environment_variables = {
    BUCKET_NAME = "gildarck-media-dev"
    BATCH_TABLE_NAME = "gildarck-batch-uploads-dev"
    MAX_RETRY_ATTEMPTS = "3"
    ENABLE_THROTTLING = "true"
  }

  tags = merge(local.tags, {
    Component = "batch-processor-v2"
    Version = "2.0"
    Features = "sqs-processing-url-generation"
  })
}
