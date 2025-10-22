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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/acm/certificate.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "gildarck.com"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../route53/zones/gildarck.com"
  ]
}

dependency "zone_root" {
  config_path = "../../route53/zones/gildarck.com"
}

# ---------------------------------------------------------------------------------------------------------------------
# Certificate configuration for main domain
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  domain_name = keys(dependency.zone_root.outputs.route53_zone_zone_id)[0]
  zone_id = values(dependency.zone_root.outputs.route53_zone_zone_id)[0]
  
  subject_alternative_names = [
    "*.${keys(dependency.zone_root.outputs.route53_zone_zone_id)[0]}"
  ]
  
  wait_for_validation = true
  tags = local.tags
}
