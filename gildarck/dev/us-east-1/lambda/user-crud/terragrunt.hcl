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
  name         = "gildarck-user-crud"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../cognito/gildarck-user-pool",
    "../../s3/media-storage"
  ]
}

dependency "cognito" {
  config_path = "../../cognito/gildarck-user-pool"
}

dependency "s3_media" {
  config_path = "../../s3/media-storage"
}

inputs = {
  function_name  = "${local.name}"
  description    = "Lambda function for user CRUD operations"
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
    cognito = {
      effect = "Allow"
      actions = [
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminDeleteUser", 
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:ListUsers",
        "cognito-idp:AdminSetUserPassword",
        "cognito-idp:AdminConfirmSignUp",
        "cognito-idp:InitiateAuth",
        "cognito-idp:SignUp",
        "cognito-idp:ChangePassword"
      ]
      resources = [dependency.cognito.outputs.user_pool.arn]
    }
    s3_access = {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = ["${dependency.s3_media.outputs.s3_bucket_arn}/*"]
    }
  }
  
  allowed_triggers = {
    APIGateway = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:us-east-1:496860676881:*/*/*"
    }
  }
  
  environment_variables = {
    USER_POOL_ID = dependency.cognito.outputs.user_pool.id
    CLIENT_ID    = dependency.cognito.outputs.clients["gildarck-web-app"].id
    REGION       = "us-east-1"
    CORS_ORIGINS = "https://dev.gildarck.com"
    S3_BUCKET    = dependency.s3_media.outputs.s3_bucket_id
  }

  tags = local.tags
}
