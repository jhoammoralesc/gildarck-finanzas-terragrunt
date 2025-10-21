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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/s3/notification.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "ic-${local.vars.ENV}-rtp-files"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../../../${local.vars.ENV}/us-east-1/s3/${local.name}",
    "../../../../${local.vars.ENV}/us-east-1/lambda/gildarck-domain-bucket-to-sftp"
  ]
}

dependency "bucket" {
  config_path = "../../../../${local.vars.ENV}/us-east-1/s3/${local.name}"
}

dependency "lambda" {
    config_path = "../../../../${local.vars.ENV}/us-east-1/lambda/gildarck-domain-bucket-to-sftp"
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  bucket = dependency.bucket.outputs.s3_bucket_id
  lambda_notifications = {
    RtpFilesToDomainBuckets = {
      function_arn = dependency.lambda.outputs.lambda_function_arn
      function_name = dependency.lambda.outputs.lambda_function_name
      events              = ["s3:ObjectCreated:*"]
      # filter_prefix       = ""
      # filter_suffix       = ".csv"
    }
  }
  tags = local.tags
}