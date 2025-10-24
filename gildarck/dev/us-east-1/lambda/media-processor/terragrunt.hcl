include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git?ref=v7.7.1"
}

dependency "s3_media" {
  config_path = "../../s3/media-storage"
}

dependency "dynamodb_metadata" {
  config_path = "../../dynamodb/media-metadata"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment = local.environment_vars.locals.environment
  aws_region = local.region_vars.locals.aws_region
  name = "gildarck-media-processor-${local.environment}"
}

inputs = {
  function_name = local.name
  description   = "Process uploaded media files and extract metadata"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 1024
  
  source_path = "./index.py"
  
  layers = [
    "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-Pillow:1"
  ]
  
  environment_variables = {
    S3_BUCKET = dependency.s3_media.outputs.s3_bucket_id
    DYNAMODB_TABLE = dependency.dynamodb_metadata.outputs.dynamodb_table_id
    REGION = local.aws_region
  }
  
  attach_policy_statements = true
  policy_statements = {
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = ["${dependency.s3_media.outputs.s3_bucket_arn}/*"]
    }
    dynamodb_access = {
      effect = "Allow"
      actions = [
        "dynamodb:PutItem",
        "dynamodb:Query"
      ]
      resources = [
        dependency.dynamodb_metadata.outputs.dynamodb_table_arn,
        "${dependency.dynamodb_metadata.outputs.dynamodb_table_arn}/index/*"
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
  
  tags = {
    Environment = local.environment
    Service     = "lambda"
    Name        = local.name
  }
}
