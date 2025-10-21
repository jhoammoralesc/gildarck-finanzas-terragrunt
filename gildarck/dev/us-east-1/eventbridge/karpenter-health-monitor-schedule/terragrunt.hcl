terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/eventbridge/rule.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "karpenter-health-monitor-schedule"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { Name = local.name })
}

dependencies {
  paths = [
    "../../lambda/karpenter-health-monitor"
  ]
}

dependency "lambda" {
  config_path = "../../lambda/karpenter-health-monitor"
}

inputs = {
  # Disable resource creation except rules and targets
  create_bus         = false
  create_role        = false
  create_permissions = true
  create_targets     = true
  
  # Create the rule
  rules = {
    (local.name) = {
      name                = local.name
      description         = "Schedule for Karpenter health monitoring - starts 10 min after services start"
      schedule_expression = "cron(10/10 10-23 ? * MON-FRI *)"
      state              = "ENABLED"
    }
  }
  
  # Create the target with correct structure
  targets = {
    (local.name) = [
      {
        name = "lambda-target"
        arn  = dependency.lambda.outputs.lambda_function_arn
      }
    ]
  }

  tags = local.tags
}
