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
  name         = "document-lot-raw-sqs"
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))

  policy_statements = {
    sqs-sender = {
      sid = "__sender_statement"
      actions = [
        "SQS:SendMessage"
      ]

      principals = [{
        type = "AWS"
        identifiers = [
          "arn:aws:iam::${local.account_vars.locals.aws_account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_infrastructure-architect-ps_41bbd9c0dc5ca2bf",
          "arn:aws:iam::${local.account_vars.locals.aws_account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_developers-ps_6b74f602f51d85bb"
        ]
      }]
    }
    sqs-receiver = {
      sid = "__receiver_statement"
      actions = [
        "SQS:ChangeMessageVisibility",
        "SQS:DeleteMessage",
        "SQS:ReceiveMessage"
      ]

      principals = [{
        type = "AWS"
        identifiers = [
          "arn:aws:iam::${local.account_vars.locals.aws_account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_infrastructure-architect-ps_41bbd9c0dc5ca2bf",
          "arn:aws:iam::${local.account_vars.locals.aws_account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_developers-ps_6b74f602f51d85bb"
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
  fifo_queue = true

  name                    = "${local.name}.fifo"
  create_queue_policy     = true
  queue_policy_statements = local.policy_statements

  dlq_name                    = "${local.name}-dlq.fifo"
  create_dlq                  = true
  create_dlq_queue_policy     = true
  dlq_queue_policy_statements = local.policy_statements

  tags = local.tags
}