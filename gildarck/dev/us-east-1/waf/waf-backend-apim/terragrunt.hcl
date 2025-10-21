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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/waf/v2.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "waf-backend-apim"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../apigateway/rtp.apim.${local.vars.ENV}.gildarck.com",
    "../../apigateway/gildarck.apim.${local.vars.ENV}.gildarck.com"
  ]
}


dependency "apim_rtp" {
  config_path = "../../apigateway/rtp.apim.${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

dependency "apim_gildarck" {
  config_path = "../../apigateway/gildarck.apim.${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {

  name = local.name

  association_resource_arns = [
    "${dependency.apim_rtp.outputs.stage_arn}",
    "${dependency.apim_gildarck.outputs.stage_arn}",
    "arn:aws:apigateway:us-east-1::/restapis/5ckq3nrgce/stages/prod"
  ]

  visibility_config = {
    cloudwatch_metrics_enabled = false
    metric_name                = "rules-waf-metric"
    sampled_requests_enabled   = false
  }

  default_action = "block"

  xss_match_statement_rules = [
    {
      name     = "rule-60-uri-PATH-contain-XSS-injection"
      action   = "block"
      priority = 60

      statement = {
        field_to_match = {
          uri_path = {}
        }

        text_transformation = [
          {
            type     = "URL_DECODE"
            priority = 1
          },
          {
            type     = "HTML_ENTITY_DECODE"
            priority = 2
          }
        ]

      }

      visibility_config = {
        cloudwatch_metrics_enabled = false
        sampled_requests_enabled   = false
        metric_name                = "rule-60-metric"
      }
    }
  ]

  sqli_match_statement_rules = [
    {
      name     = "rule-70-query-string-SQL-injection"
      action   = "block"
      priority = 70

      statement = {

        field_to_match = {
          query_string = {}
        }

        text_transformation = [
          {
            type     = "URL_DECODE"
            priority = 1
          },
          {
            type     = "HTML_ENTITY_DECODE"
            priority = 2
          }
        ]

      }

      visibility_config = {
        cloudwatch_metrics_enabled = false
        sampled_requests_enabled   = false
        metric_name                = "rule-70-metric"
      }
    }
  ]

  regex_match_statement_rules = [
    {
      name     = "rule-100-admin-path"
      priority = 100
      action   = "block"

      statement = {
        regex_string = "^/admin"

        text_transformation = [
          {
            priority = 90
            type     = "COMPRESS_WHITE_SPACE"
          }
        ]

        field_to_match = {
          uri_path = {}
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = false
        sampled_requests_enabled   = false
        metric_name                = "rule-100-metric"
      }
    }
  ]

  ip_set_reference_statement_rules = [
    {
      name     = "rule-white-list-ip-110-rule"
      priority = 110
      action   = "allow"

      statement = {
        arn = "arn:aws:wafv2:us-east-1:559756754086:regional/ipset/white-list-ip-apim/52d429fe-7976-41d0-a734-ec70935f3b15"
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = false
        metric_name                = "rule-white-list-ip-apim-metric"
      }
    }
  ]

  tags = local.tags
}