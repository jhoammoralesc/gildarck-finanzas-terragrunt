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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/sqs/sqs.hcl"
  expose = true
}

locals {
  name         = "karpenter-interruption-sqs"
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))

  policy_statements = {
    events-sender = {
      sid    = "EC2InterruptionPolicy"
      effect = "Allow"
      actions = [
        "SQS:SendMessage"
      ]
      principals = [{
        type = "Service"
        identifiers = [
          "events.amazonaws.com",
          "sqs.amazonaws.com"
        ]
      }]
    }
  }

  tags = merge(local.service_vars.locals.tags, { name = local.name })
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name                    = "${local.name}"
  create_queue_policy     = true
  queue_policy_statements = local.policy_statements
  tags                    = local.tags
}