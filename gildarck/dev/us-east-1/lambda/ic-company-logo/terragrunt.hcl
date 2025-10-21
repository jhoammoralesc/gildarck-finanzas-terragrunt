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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/lambda/function.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "ic-company-logo"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = ["../../s3/ic-${local.vars.ENV}-lambdas-bucket"]
}

dependency "bucket" {
  config_path = "../../s3/ic-${local.vars.ENV}-lambdas-bucket"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  function_name  = "${local.name}"
  description    = "Lambda ic-company-logo to get resize images."
  handler        = "company_logo_handler.company_logo_handler"
  runtime        = "python3.12"
  publish        = true
  create_role    = true
  create_package = false
  timeout        = 15

  s3_existing_package = {
    bucket     = "${dependency.bucket.outputs.s3_bucket_id}"
    key        = "${local.name}.zip"
    version_id = null
  }

  attach_policy_statements = true

  policy_statements = {
    S3GetObjectPermission = {
      effect    = "Allow",
      actions   = ["s3:GetObject"],
      resources = ["arn:aws:s3:::ic-${local.vars.ENV}-company-logo/*"]
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