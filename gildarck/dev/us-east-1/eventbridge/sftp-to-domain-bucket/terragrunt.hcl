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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/eventbridge/rule.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "sftp-to-domain-bucket"
  branch_name  = local.vars.AMPLIFY_BRANCH
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../lambda/gildarck-sftp-to-domain-bucket"
  ]
}


dependency "lambda" {
  config_path = "../../lambda/gildarck-sftp-to-domain-bucket"
  #skip_outputs = true
}
# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  create_bus = false
  role_name = "sftp-to-domain-bucket-eventbridge"
  rules = {
    sftp-to-domain-bucket = {
      description = "Rule triggered when files are created in the SFTP S3 bucket"
      event_pattern = jsonencode(
        {
          "source" : ["aws.s3"],
          "detail-type": ["Object Created"],
          "detail" : {
            "bucket" : {
              "name" : ["gildarck-${local.vars.ENV}-client-sftp-files"]
            }
          }
        }
      )
    }
  }

  targets = {
    sftp-to-domain-bucket = [
      {
        name = "MoveFilesFromSftpToDomainBucket"
        arn  = dependency.lambda.outputs.lambda_function_arn
      }
    ]
  }
}