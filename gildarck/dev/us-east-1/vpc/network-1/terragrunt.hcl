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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/vpc/network.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "network-1"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = local.name
  cidr = local.vars.CIDR
  azs  = local.vars.AZS

  private_subnets = local.vars.PRIVATE_SUBNETS
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = 1,
    "kubernetes.io/cluster/eks-${local.vars.ENV}-1" = "dev",
    "karpenter.sh/discovery"                        = "eks-${local.vars.ENV}-1"
  }

  public_subnets = local.vars.PUBLIC_SUBNETS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = 1,
    "kubernetes.io/cluster/eks-${local.vars.ENV}-1" = "shared"
  }

  database_subnets = local.vars.DATABASE_SUBNETS

  enable_nat_gateway     = local.vars.ENABLE_NAT_GATEWAY
  single_nat_gateway     = local.vars.SINGLE_NAT_GATEWAY
  one_nat_gateway_per_az = local.vars.ONE_NAT_GATEWAY_PER_AZ
  enable_dns_hostnames   = local.vars.ENABLE_DNS_HOSTNAMES
  enable_dns_support     = local.vars.ENABLE_DNS_SUPPORT

  # Route Tables
  public_route_table_tags = {
    Name = "${local.name}-public"
  }

  private_route_table_tags = {
    Name = "${local.name}-private"
  }

  database_route_table_tags = {
    Name = "${local.name}-database"
  }

  tags = local.tags
}