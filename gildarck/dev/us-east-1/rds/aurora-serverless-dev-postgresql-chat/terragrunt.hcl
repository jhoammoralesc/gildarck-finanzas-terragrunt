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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/rds/aurora.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "aurora-serverless-${local.vars.ENV}-postgresql-chat"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = ["../../vpc/network-1", "../../../../network/us-east-1/vpc/network-1/"]
}

dependency "vpc" {
  config_path = "../../vpc/network-1"
  #skip_outputs = true
}

dependency "vpc_network" {
  config_path = "../../../../network/us-east-1/vpc/network-1/"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {

  name                                = "${local.name}"
  engine                              = "aurora-postgresql"
  engine_mode                         = "provisioned"
  storage_encrypted                   = true
  engine_version                      = "14.15"
  create_db_parameter_group           = true
  db_parameter_group_family           = "aurora-postgresql14"
  instance_class                      = "db.serverless"
  ca_cert_identifier                  = "rds-ca-rsa2048-g1"
  iam_database_authentication_enabled = true
  instances = {
    one = {}
    // two = {} //Uncomment in prod workloads to create a reader instance 
  }
  serverlessv2_scaling_configuration = {
    min_capacity = 1
    max_capacity = 10
  }

  vpc_id               = dependency.vpc.outputs.vpc_id
  db_subnet_group_name = dependency.vpc.outputs.database_subnet_group_name
  security_group_rules = {
    vpc_dev_ingress = {
      cidr_blocks = dependency.vpc.outputs.private_subnets_cidr_blocks
    }

    vpc_network_ingress = {
      cidr_blocks = dependency.vpc_network.outputs.private_subnets_cidr_blocks
    }
  }

  master_username = local.vars.POSTGRESQL_CHAT_USERNAME
  master_password = local.vars.POSTGRESQL_CHAT_PASSWORD

  manage_master_user_password = false

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  # enabled_cloudwatch_logs_exports = # NOT SUPPORTED

  tags = local.tags
}