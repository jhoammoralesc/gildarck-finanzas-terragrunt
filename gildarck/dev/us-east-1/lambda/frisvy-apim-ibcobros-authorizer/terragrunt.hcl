# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# We override the terraform block source attribute here just for the QA environment to show how you would deploy a
# different version of the module in a specific environment.
terraform {
  source = "${include.envcommon.locals.base_source_url}"
  before_hook "create_lambda_zip" {
    commands = ["apply", "plan"]
    execute  = ["bash", "-c", "cd lambda && npm install && zip -r ../gildarck-apim-gildarck-authorizer.zip index.js node_modules && cd .."]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Include configurations that are common used across multiple environments.
# ---------------------------------------------------------------------------------------------------------------------

# Include the root `terragrunt.hcl` configuration. The root configuration contains settings that are common across all
# components and environments, such as how to configure remote state.
include "root" {
  path = find_in_parent_folders()
}

# Include the envcommon configuration for the component. The envcommon configuration contains settings that are common
# for the component across all environments.
include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/lambda/function.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "gildarck-apim-gildarck-authorizer"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  function_name                     = "${local.name}"
  description                       = "Lambda function with authorization logic for APIM gildarck APIs."
  handler                           = "index.handler"
  runtime                           = "nodejs22.x"
  architectures                     = ["arm64"]
  publish                           = true
  timeout                           = 20
  create_package                    = false
  cloudwatch_logs_retention_in_days = 7
  local_existing_package            = "gildarck-apim-gildarck-authorizer.zip"
  memory_size                       = 1024

  environment_variables = {
    USER_POOL_ID = "us-east-1_SqRB9UaHj"
  }

  attach_policy_statements = true
  policy_statements = {
    ParameterStore = {
      effect    = "Allow",
      actions   = ["cognito-idp:AdminGetUser"],
      resources = ["*"]
    }
  }

  allowed_triggers = {
    APIGatewayAny = {
      service  = "apigateway"
      resource = "arn:aws:lambda:${local.tags.region}:${local.aws_account_id}:function:${local.name}"
    }
  }

  tags = local.tags
}
