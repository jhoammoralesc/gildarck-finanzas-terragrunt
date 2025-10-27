terraform {
  source = "git@github.com:jhoammoralesc/infrastructure-terraform-modules.git//aws-lambda"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "sqs" {
  config_path = "../../sqs/thumbnail-queue"
}

dependency "s3" {
  config_path = "../../s3/media-storage"
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "gildarck-thumbnail-generator"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = local.name
  description    = "Generate thumbnails for uploaded images"
  handler        = "index.lambda_handler"
  runtime        = "python3.12"
  timeout        = 300
  memory_size    = 512
  publish        = true
  create_role    = true
  create_package = false

  local_existing_package = "lambda-simple-layer.zip"
  
  # Use public Pillow layer only
  layers = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-pillow:1"]

  attach_policy_statements = true
  policy_statements = {
    S3Access = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = ["${dependency.s3.outputs.s3_bucket_arn}/*"]
    }
    SQSAccess = {
      effect = "Allow"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      resources = [dependency.sqs.outputs.queue_arn]
    }
  }

  event_source_mapping = {
    sqs = {
      event_source_arn = dependency.sqs.outputs.queue_arn
      batch_size       = 1
    }
  }

  environment_variables = {
    S3_BUCKET      = dependency.s3.outputs.s3_bucket_id
    SQS_QUEUE_URL  = dependency.sqs.outputs.queue_url
  }

  tags = local.tags
}
