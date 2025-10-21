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
  name         = "karpenter-recovery-schedule"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { Name = local.name })
}

dependencies {
  paths = [
    "../../lambda/karpenter-recovery"
  ]
}

dependency "lambda" {
  config_path = "../../lambda/karpenter-recovery"
}

inputs = {
  create_bus         = false
  create_role        = false
  create_permissions = true
  create_targets     = true
  
  rules = {
    (local.name) = {
      name         = local.name
      description  = "Trigger for Karpenter recovery when health check fails"
      event_pattern = jsonencode({
        source      = ["karpenter.health.monitor"]
        detail-type = ["Karpenter Health Check Failed"]
        detail = {
          status = ["NOT_READY"]
        }
      })
      state = "ENABLED"
    }
  }
  
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
