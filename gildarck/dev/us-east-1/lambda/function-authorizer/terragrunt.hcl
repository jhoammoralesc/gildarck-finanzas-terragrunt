# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "git@github.com:jhoammoralesc/infrastructure-terraform-modules.git//aws-lambda"
}

# ---------------------------------------------------------------------------------------------------------------------
# Include configurations that are common used across multiple environments.
# ---------------------------------------------------------------------------------------------------------------------

# Include the root `terragrunt.hcl` configuration. The root configuration contains settings that are common across all
# components and environments, such as how to configure remote state.
include "root" {
  path = find_in_parent_folders()
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "gildarck-authorizer"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name  = local.name
  description    = "Lambda authorizer for GILDARCK Photo API - validates JWT tokens"
  handler        = "index.handler"
  runtime        = "nodejs22.x"
  publish        = true
  create_role    = true
  create_package = false
  timeout        = 5
  memory_size    = 512

  local_existing_package = "lambda-authorizer.zip"

  environment_variables = {
    AUTH_SECRET = "gildarck-jwt-secret"
    AUDIENCE    = "gildarck-photo-api"
  }

  attach_policy_statements = true
  policy_statements = {
    ParameterStore = {
      effect    = "Allow",
      actions   = ["ssm:GetParameter", "ssm:PutParameter"],
      resources = ["arn:aws:ssm:${local.tags.region}:${local.aws_account_id}:parameter/gildarck-jwt-secret"]
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
