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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/transfer-family/sftp.hcl"
  expose = true
}

locals {
  name         = "sftp-1"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../vpc/network-1",
    "../../s3/ic-dev-sftp-1",
    "../../security-group/sftp-1-vpc-endpoint-sg",
    "../../route53/zones/dev.gildarck.com"
  ]
}

dependency "zone_root" {
  config_path = "../../route53/zones/dev.gildarck.com"
  #skip_outputs = true
}

dependency "sg" {
  config_path = "../../security-group/sftp-1-vpc-endpoint-sg"
}

dependency "bucket" {
  config_path = "../../s3/ic-dev-sftp-1"
  #skip_outputs = true
}

dependency "vpc" {
  config_path = "../../vpc/network-1"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = local.name

  eip_enabled = true

  s3_bucket_name  = dependency.bucket.outputs.s3_bucket_id
  restricted_home = true
  sftp_users = {
    "santiago" = {
      user_name  = "santiago",
      public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDPLmZv74yUx+pDBUDJJ1p+VRIihNjMJaNvyGQY6I/4gV8n45lK/1Ok7qTiSqFZHU1QYzq7Z6UgoE0QcPZw8lhGk34lkG4OlOtFCNb8J20q480Evyqvmraqy58WGU8vKv/LVwNGdw1AtsYHMK7Qk9/JJCDoASQ1tyq04eStsRScQ4QsdYhNNDrD3jNR6V2EIUVWcSNyCzJ/dE7lXWxfB1dcKOOCZ0mkSPBqo2OmfyORqA7bM5X6+FI89PN21TefRq0Ds69MZmBhR0FybbTr2KXlRetxAcWg1NbAgmAvccrdNACWLUZuIZ+ZEyvxo2mMs+5cV0tvQYeIWEbJ9VR+2pMzukBa6e2jYuIZxlSQB8rmHjgbeV9R0OSZZLChuY6b38xoCA+DxFE2u5DgfzVi3T4kWEp+375dG3nnMAGdCDLWUQ6bkXj4XN0aIRqIDzxh2+Fk1Jb2tehQjzBWTRA9qPb9aCLwroJe+xH3Wn6OBKwnhw3BqfBRiJ0s7t1DSiTjVr0= hocknas@master.local"
    }
  }

  eip_domain = "vpc"
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = [dependency.vpc.outputs.public_subnets[2]]

  vpc_security_group_ids = [dependency.sg.outputs.security_group_id]

  security_policy_name = "TransferSecurityPolicy-2024-01"

  domain_name = "sftp.dev.gildarck.com"
  zone_id     = values(dependency.zone_root.outputs.route53_zone_zone_id)[0]
  tags        = local.tags
}