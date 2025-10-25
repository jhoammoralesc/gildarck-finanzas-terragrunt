# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

# ---------------------------------------------------------------------------------------------------------------------
# Include configurations that are common used across multiple environments.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/ses/identity.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "${local.vars.ENV}.gildarck.com"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../route53/zones/${local.vars.ENV}.gildarck.com"
  ]
}

dependency "zone_root" {
  config_path = "../../route53/zones/${local.vars.ENV}.gildarck.com"
}

# ---------------------------------------------------------------------------------------------------------------------
# SES Configuration for GILDARCK
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  domain = keys(dependency.zone_root.outputs.route53_zone_zone_id)[0]
  zone_id = values(dependency.zone_root.outputs.route53_zone_zone_id)[0]
  
  verify_dkim = true
  verify_domain = true
  
  ses_group_enabled = false
  create_iam_access_key = false
  
  tags = local.tags
}
