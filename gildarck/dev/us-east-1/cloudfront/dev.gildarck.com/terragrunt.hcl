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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/cloudfront/distribution.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = local.vars.AMPLIFY_DNS
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  environment    = local.vars.AMPLIFY_BRANCH
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../waf/waf-fronted",
    "../../amplify/${local.vars.ENV}.gildarck.com",
    "../../acm/${local.vars.ENV}.gildarck.com"
  ]
}

dependency "waf" {
  config_path = "../../waf/waf-fronted"
  #skip_outputs = true
}

dependency "amplify" {
  config_path = "../../amplify/${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

dependency "acm" {
  config_path = "../../acm/${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  aliases         = [local.name]
  comment         = "Cloudfront distribution to amplify App."
  is_ipv6_enabled = false
  price_class     = "PriceClass_All"
  web_acl_id      = dependency.waf.outputs.arn

  origin = {
    amplify-app = {
      domain_name = "${local.vars.ENV}.${dependency.amplify.outputs.default_domain}"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
      custom_header = [
        {
          name  = "Authorization"
          value = "Basic ${local.vars.AMPLIFY_CREDENTIALS}"
        }
      ]
    }
  }

  default_cache_behavior = {
    target_origin_id       = "amplify-app"
    viewer_protocol_policy = "allow-all"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" //Disabled cache policy
    use_forwarded_values   = false
    compress               = true
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]

    lambda_function_association = {
      viewer-request = {
        include_body = true
        lambda_arn   = "arn:aws:lambda:us-east-1:${local.aws_account_id}:function:auth-amplify-app-edge-function:1"
      }
    }
  }

  viewer_certificate = {
    acm_certificate_arn = dependency.acm.outputs.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  tags = local.tags
}