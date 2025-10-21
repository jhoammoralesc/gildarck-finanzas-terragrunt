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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/cloudfront-s3/static-web.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "company-logo"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../route53/zones/${local.vars.ENV}.gildarck.com",
    "../../s3/ic-${local.vars.ENV}-company-logo",
    "../../acm/${local.vars.ENV}.gildarck.com"
  ]
}

dependency "zone_root" {
  config_path = "../../route53/zones/${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

dependency "bucket" {
  config_path = "../../s3/ic-${local.vars.ENV}-company-logo"
  #skip_outputs = true
}

dependency "acm" {
  config_path = "../../acm/${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}
# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  origin_bucket = dependency.bucket.outputs.s3_bucket_id
  // price_class                       = "PriceClass_All"
  cors_allowed_origins              = ["*"]
  cors_allowed_methods              = ["GET", "HEAD"]
  cloudfront_access_logging_enabled = false
  acm_certificate_arn               = dependency.acm.outputs.acm_certificate_arn
  aliases                           = ["assets.${local.vars.ENV}.gildarck.com"]
  dns_alias_enabled                 = true
  parent_zone_name                  = values(dependency.zone_root.outputs.route53_zone_name)[0]
  cache_policy_id                   = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" //Disabled cache policy
  default_ttl                       = 0
  max_ttl                           = 0
  tags                              = local.tags
}