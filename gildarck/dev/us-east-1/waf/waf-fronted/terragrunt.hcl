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
  name         = "waf-fronted"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {

  name = local.name

  visibility_config = {
    cloudwatch_metrics_enabled = false
    metric_name                = "rules-waf-metric"
    sampled_requests_enabled   = false
  }

  default_action = "allow"

  scope = "CLOUDFRONT"

  managed_rule_group_statement_rules = [
    {
      name     = "AWS-AWSManagedRulesAdminProtectionRuleSet"
      priority = 1

      statement = {
        name        = "AWSManagedRulesAdminProtectionRuleSet"
        vendor_name = "AWS"
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "AWS-AWSManagedRulesAdminProtectionRuleSet"
      }
    },
    {
      name     = "AWS-AWSManagedRulesAmazonIpReputationList"
      priority = 2

      statement = {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      }
    },
    {
      name     = "AWS-AWSManagedRulesCommonRuleSet"
      priority = 3

      statement = {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      }
    },
    {
      name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      priority = 4

      statement = {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      }
    },
    # https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-bot.html
    {
      name     = "AWS-AWSManagedRulesBotControlRuleSet"
      priority = 5

      statement = {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        rule_action_override = {
          CategoryHttpLibrary = {
            action = "count"
            custom_response = {
              response_code = "404"
              response_header = {
                name  = "example-1"
                value = "example-1"
              }
            }
          }
          SignalNonBrowserUserAgent = {
            action = "count"
            custom_request_handling = {
              insert_header = {
                name  = "example-2"
                value = "example-2"
              }
            }
          }
          CategorySocialMedia = {
            action = "count"
          }
        }

        managed_rule_group_configs = [
          {
            aws_managed_rules_bot_control_rule_set = {
              inspection_level = "COMMON"
            }
          }
        ]
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "AWS-AWSManagedRulesBotControlRuleSet"
      }
    }
  ]

  byte_match_statement_rules = [
    {
      name     = "rule-30-cp-key-path"
      action   = "count"
      priority = 30

      statement = {
        positional_constraint = "EXACTLY"
        search_string         = "/cp-key"

        text_transformation = [
          {
            priority = 30
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
        metric_name                = "rule-30-metric"
      }
    }
  ]

  rate_based_statement_rules = [
    {
      name     = "rule-40-request-limits-by-IPs"
      action   = "count"
      priority = 40

      statement = {
        limit              = 2500
        aggregate_key_type = "IP"
      }

      visibility_config = {
        cloudwatch_metrics_enabled = false
        sampled_requests_enabled   = false
        metric_name                = "rule-40-metric"
      }
    }
  ]

  // size_constraint_statement_rules = [
  //   {
  //     name     = "rule-50"
  //     action   = "count"
  //     priority = 50

  //     statement = {
  //       comparison_operator = "GT"
  //       size                = 15

  //       field_to_match = {
  //         all_query_arguments = {}
  //       }

  //       text_transformation = [
  //         {
  //           type     = "COMPRESS_WHITE_SPACE"
  //           priority = 1
  //         }
  //       ]

  //     }

  //     visibility_config = {
  //       cloudwatch_metrics_enabled = false
  //       sampled_requests_enabled   = false
  //       metric_name                = "rule-50-metric"
  //     }
  //   }
  // ]

  xss_match_statement_rules = [
    {
      name     = "rule-60-uri-PATH-contain-XSS-injection"
      action   = "count"
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
      action   = "count"
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

  // geo_match_statement_rules = [
  //   {
  //     name     = "rule-80"
  //     action   = "count"
  //     priority = 80

  //     statement = {
  //       country_codes = ["NL", "GB"]
  //     }

  //     visibility_config = {
  //       cloudwatch_metrics_enabled = false
  //       sampled_requests_enabled   = false
  //       metric_name                = "rule-80-metric"
  //     }
  //   },
  //   {
  //     name     = "rule-11"
  //     action   = "count"
  //     priority = 11

  //     statement = {
  //       country_codes = ["US"]
  //     }

  //     visibility_config = {
  //       cloudwatch_metrics_enabled = false
  //       sampled_requests_enabled   = false
  //       metric_name                = "rule-11-metric"
  //     }
  //   }
  // ]

  // geo_allowlist_statement_rules = [
  //   {
  //     name     = "rule-90"
  //     priority = 90

  //     statement = {
  //       country_codes = ["AR", "CO", "UY", "MX"]
  //     }

  //     visibility_config = {
  //       cloudwatch_metrics_enabled = false
  //       sampled_requests_enabled   = false
  //       metric_name                = "rule-90-metric"
  //     }
  //   }
  // ]

  regex_match_statement_rules = [
    {
      name     = "rule-100-admin-path"
      priority = 100
      action   = "count"

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

  // ip_set_reference_statement_rules = [
  //   {
  //     name     = "rule-110"
  //     priority = 110
  //     action   = "count"

  //     statement = {
  //       ip_set = {
  //         ip_address_version = "IPV4"
  //         addresses          = ["17.0.0.0/8"]
  //       }
  //     }

  //     visibility_config = {
  //       cloudwatch_metrics_enabled = false
  //       sampled_requests_enabled   = false
  //       metric_name                = "rule-110-metric"
  //     }
  //   }
  // ]

  tags = local.tags
}