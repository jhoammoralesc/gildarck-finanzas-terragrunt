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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/vpc/endpoints.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "secret-manager-interface-endpoint"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../../../${local.vars.ENV}/us-east-1/vpc/network-1",
    "../../../../${local.vars.ENV}/us-east-1/security-group/secret-manager-vpc-endpoint-sg"
  ]
}

dependency "vpc" {
  config_path = "../../../../${local.vars.ENV}/us-east-1/vpc/network-1"
  #skip_outputs = true
}

dependency "security-group" {
  config_path = "../../../../${local.vars.ENV}/us-east-1/security-group/secret-manager-vpc-endpoint-sg"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  endpoints = {
    secret-manager = {
      service_name        = "com.amazonaws.${local.tags.region}.secretsmanager"
      vpc_endpoint_type   = "Interface"
      private_dns_enabled = true
      subnet_ids          = slice(dependency.vpc.outputs.private_subnets, 0, 3)
      security_group_ids  = [dependency.security-group.outputs.security_group_id]
    }
  }
  tags = local.tags
}