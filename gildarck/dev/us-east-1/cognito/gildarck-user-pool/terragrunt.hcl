# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - GILDARCK USER POOL
# Simplified Cognito configuration for GILDARCK project
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

# ---------------------------------------------------------------------------------------------------------------------
# Include configurations that are common used across multiple environments.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/cognito/user-pool.hcl"
  expose = true
}

locals {
  vars             = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  invitation_email = file("./email/${local.vars.ENV}/invitation.html")
  recovery_email   = file("./email/${local.vars.ENV}/password-reset.html")
  name             = local.vars.COGNITO_USER_POOL_NAME
  service_vars     = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags             = merge(local.service_vars.locals.tags, { name = local.name })
}

# ---------------------------------------------------------------------------------------------------------------------
# SIMPLIFIED COGNITO CONFIGURATION FOR GILDARCK
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name   = local.name
  domain = local.vars.COGNITO_DOMAIN_PREFIX

  # Allow user self-registration
  allow_admin_create_user_only = false
  enable_username_case_sensitivity = false
  advanced_security_mode = "ENFORCED"

  # Authentication attributes
  alias_attributes = ["email"]
  auto_verified_attributes = ["email"]

  # OAuth configuration for web applications
  default_client_allowed_oauth_scopes = [
    "aws.cognito.signin.user.admin",
    "openid",
    "email",
    "profile"
  ]

  default_client_allowed_oauth_flows = ["code"]
  default_client_generate_secret = false
  default_client_enable_token_revocation = true

  # Authentication flows
  default_client_explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Token validity
  default_client_token_validity_units = {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Device tracking
  challenge_required_on_new_device = true
  user_device_tracking = "USER_OPT_IN"

  # Password policy
  password_require_lowercase = true
  password_require_numbers   = true
  password_require_uppercase = true
  password_require_symbols   = false
  password_minimum_length    = 8
  temporary_password_validity_days = 7

  # Application clients
  clients = [
    {
      name = "gildarck-web-app"
      read_attributes = [
        "email", 
        "email_verified", 
        "preferred_username",
        "custom:role",
        "custom:company"
      ]
      allowed_oauth_scopes = [
        "aws.cognito.signin.user.admin",
        "openid",
        "email",
        "profile"
      ]
      allowed_oauth_flows = ["code"]
      callback_urls = [
        "https://${local.vars.ENV}.gildarck.com/auth/callback",
        "https://bo.${local.vars.ENV}.gildarck.com/auth/callback"
      ]
      logout_urls = [
        "https://${local.vars.ENV}.gildarck.com/auth/logout",
        "https://bo.${local.vars.ENV}.gildarck.com/auth/logout"
      ]
      default_redirect_uri = "https://${local.vars.ENV}.gildarck.com/auth/callback"
    }
  ]

  # Custom attributes for GILDARCK
  schema_attributes = [
    {
      name       = "role"
      type       = "String"
      required   = false
      min_length = 1
      max_length = 50
    },
    {
      name       = "company"
      type       = "String"
      required   = false
      min_length = 1
      max_length = 100
    }
  ]

  # Email configuration - using Cognito default email
  invite_email_subject  = "Bienvenido a GILDARCK"
  email_subject         = "Recuperar contraseña - GILDARCK"
  invite_email_message  = local.invitation_email
  email_message         = local.recovery_email
  email_sending_account = "COGNITO_DEFAULT"

  tags = local.tags
}