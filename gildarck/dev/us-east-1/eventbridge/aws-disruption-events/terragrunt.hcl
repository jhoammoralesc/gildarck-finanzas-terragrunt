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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/eventbridge/rule.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  name         = "aws-disruption-events"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../sqs/karpenter-interruption-sqs"
  ]
}


dependency "sqs" {
  config_path = "../../sqs/karpenter-interruption-sqs"
  #skip_outputs = true
}
# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  create_bus = false
  role_name  = "eventbridge-aws-disruption-events"
  rules = {
    aws-disruption-events = {
      description = "Rule to listen AWS events for interruption EC2 workloads."
      event_pattern = jsonencode(
        {
          "source" : ["aws.health", "aws.ec2"],
          "detail-type" : ["AWS Health Event", "EC2 Spot Instance Interruption Warning", "EC2 Instance Rebalance Recommendation", "EC2 Instance State-change Notification"],
          "detail" : {
            "eventRegion" : [local.region_vars.aws_region]
          }
        }
      )
    }
  }

  targets = {
    aws-disruption-events = [
      {
        name = "interruption-events-to-sqs"
        arn  = dependency.sqs.outputs.queue_arn
      }
    ]
  }
}