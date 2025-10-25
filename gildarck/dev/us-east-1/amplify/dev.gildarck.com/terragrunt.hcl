# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# We override the terraform block source attribute here just for the QA environment to show how you would deploy a
# different version of the module in a specific environment.
terraform {
  source = "${include.envcommon.locals.base_source_url}"
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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/amplify/amplify.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "gildarck"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = ["../../iam/amplify-role"]
}

dependency "amplify-role" {
  config_path = "../../iam/amplify-role"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  access_token         = local.vars.AMPLIFY_GIT_TOKEN
  name                 = local.name
  description          = local.name
  repository           = local.vars.AMPLIFY_GIT_SOURCE
  platform             = "WEB_COMPUTE"
  service_role_arn     = dependency.amplify-role.outputs.iam_role_arn

  enable_auto_branch_creation = false
  enable_branch_auto_build    = true
  enable_branch_auto_deletion = false
  enable_basic_auth           = true
  basic_auth_credentials      = local.vars.AMPLIFY_CREDENTIALS

  custom_rules = [
    {
      source = "/<*>"
      status = "404-200"
      target = "/index.html"
    }
  ]

  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - nvm i 22
            - npm ci --ignore-scripts
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: .next
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
    compute:
      type: STANDARD_2GB
  EOT

  environment_variables = local.vars.AMPLIFY_VARIABLES

  environments = {
    develop = {
      enable_notification         = true
      branch_name                 = "${local.vars.AMPLIFY_BRANCH}"
      enable_auto_build           = true
      backend_enabled             = false
      enable_performance_mode     = false
      enable_pull_request_preview = false
      framework                   = "Next.js - SSR"
      stage                       = "PRODUCTION"
      ttl                         = 5
    }
  }
  
  # domain_config = {
  #   domain_name            = local.vars.AMPLIFY_DNS
  #   enable_auto_sub_domain = false
  #   wait_for_verification  = false
  #   sub_domain = [
  #     {
  #       branch_name = "develop"
  #       prefix      = ""
  #     }
  #   ]
  # }
}