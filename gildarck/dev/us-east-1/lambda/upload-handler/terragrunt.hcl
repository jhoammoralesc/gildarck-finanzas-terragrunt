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
  name         = "gildarck-upload-handler"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../s3/media-storage",
    "../../sqs/media-processing-queue"
  ]
}

dependency "s3_media" {
  config_path = "../../s3/media-storage"
}

dependency "sqs_queue" {
  config_path = "../../sqs/media-processing-queue"
}

inputs = {
  function_name  = "${local.name}"
  description    = "Handles multipart file uploads to S3 with chunking support"
  handler        = "index.lambda_handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  timeout        = 30
  memory_size    = 512
  create_package = false
  publish        = true

  local_existing_package = "lambda.zip"
  
  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:CreateMultipartUpload",
        "s3:CompleteMultipartUpload",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:GetObject"
      ]
      resources = [
        dependency.s3_media.outputs.s3_bucket_arn,
        "${dependency.s3_media.outputs.s3_bucket_arn}/*"
      ]
    }
    sqs_access = {
      effect = "Allow"
      actions = [
        "sqs:SendMessage"
      ]
      resources = [dependency.sqs_queue.outputs.queue_arn]
    }
  }
  
  allowed_triggers = {
    APIGateway = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:us-east-1:496860676881:*/*/*"
    }
  }
  
  environment_variables = {
    S3_BUCKET     = dependency.s3_media.outputs.s3_bucket_id
    SQS_QUEUE_URL = dependency.sqs_queue.outputs.queue_url
    REGION        = "us-east-1"
    CORS_ORIGINS  = "https://dev.gildarck.com"
  }

  tags = local.tags
}
