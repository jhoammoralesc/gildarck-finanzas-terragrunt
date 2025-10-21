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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/transit-gateway/shared.hcl"
  expose = true
}

locals {
  name         = "attachment-2"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = ["../../vpc/network-1", "../../../../network/us-east-1/transit-gateway/shared-1"]
}

dependency "vpc" {
  config_path = "../../vpc/network-1"
  #skip_outputs = true
}

dependency "tgw_network" {
  config_path = "../../../../network/us-east-1/transit-gateway/shared-1"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name        = local.name
  description = "Only Transit Gateway Attachment to connect with several other AWS accounts"

  create_tgw             = false
  share_tgw              = true
  ram_resource_share_arn = dependency.tgw_network.outputs.ram_resource_share_id

  enable_auto_accept_shared_attachments = true

  vpc_attachments = {

    vpc_dev = {

      tgw_id = dependency.tgw_network.outputs.ec2_transit_gateway_id

      vpc_id       = dependency.vpc.outputs.vpc_id
      subnet_ids   = dependency.vpc.outputs.natted_subnets
      dns_support  = true
      ipv6_support = false

      transit_gateway_default_route_table_association = true
      transit_gateway_default_route_table_propagation = true

    }
  }

  tags = local.tags
}