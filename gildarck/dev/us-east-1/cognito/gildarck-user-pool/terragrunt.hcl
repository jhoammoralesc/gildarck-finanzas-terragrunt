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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/cognito/user-pool.hcl"
  expose = true
}

locals {
  vars             = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  invitation_email = file("./email/${local.vars.ENV}/invitation.html")
  recovery_email   = file("./email/${local.vars.ENV}/password-reset.html")
  name             = "gildarck-user-pool"
  aws_account_id   = "559756754086"
  service_vars     = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags             = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../lambda/ic-apim-cognito-pre-token-generation-lambda"
  ]
}

dependency "lambda_pre_login" {
  config_path = "../../lambda/ic-apim-cognito-pre-token-generation-lambda"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = local.name

  domain = local.name

  # We allow the public to create user profiles
  allow_admin_create_user_only = true

  enable_username_case_sensitivity = false
  advanced_security_mode           = "ENFORCED"

  //Toca cambiar por consola el Trigger event Version a la V2 para que pueda funcionar
  //No hay soporte para setear la V2 en terraform
  lambda_pre_token_generation = dependency.lambda_pre_login.outputs.lambda_function_arn

  alias_attributes = [
    "email",
    "preferred_username"
  ]

  auto_verified_attributes = [
    "email"
  ]

  default_client_allowed_oauth_scopes = [
    "aws.cognito.signin.user.admin",
    "openid"
  ]

  default_client_allowed_oauth_flows = [
    "code",
    "implicit"
  ]

  default_client_token_validity_units = {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  default_client_enable_token_revocation = true

  challenge_required_on_new_device = true
  user_device_tracking             = "USER_OPT_IN"

  password_require_lowercase = true
  password_require_numbers   = true
  password_require_uppercase = true
  password_require_symbols   = true

  temporary_password_validity_days = 3

  default_client_token_validity_units = {
    refresh_token = "days"
    access_token  = "hours"
    id_token      = "hours"
  }

  attribute_mapping = {
    email    = "email"
    nickname = "groupId"
  }

  default_client_generate_secret = false

  default_client_explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  password_minimum_length = 10

  clients = [
    {
      name            = "apim"
      read_attributes = ["email", "email_verified", "preferred_username", "nickname", "custom:IPs", "custom:commercial_id", "custom:company", "custom:requested_scopes"]
      allowed_oauth_scopes = [
        "aws.cognito.signin.user.admin",
        "openid"
      ]
      allowed_oauth_flows  = ["implicit", "code"]
      callback_urls        = ["https://portal.apim.${local.vars.ENV}.gildarck.com"]
      logout_urls          = ["https://portal.apim.${local.vars.ENV}.gildarck.com"]
      default_redirect_uri = "https://portal.apim.${local.vars.ENV}.gildarck.com"
    }
  ]

  schema_attributes = [
    {
      name       = "IPs",
      type       = "String"
      required   = false
      min_length = 8
      max_length = 256
    },
    {
      name       = "commercial_id",
      type       = "String"
      required   = false
      min_length = 6
      max_length = 25
    },
    {
      name       = "commercial_id_type",
      type       = "String"
      required   = false
      min_length = 1
      max_length = 25
    },
    {
      name       = "company",
      type       = "String"
      required   = false
      min_length = 1
      max_length = 50
    },
    {
      name       = "requested_scopes",
      type       = "String"
      required   = false
      min_length = 1
      max_length = 500
    }
  ]

  invite_email_subject  = "Bienvenido(a) gildarck Api Manager"
  email_subject         = "Recuperar contraseña gildarck Api Manager"
  invite_email_message  = local.invitation_email
  email_message         = local.recovery_email
  email_sending_account = "DEVELOPER"
  email_source_arn      = "arn:aws:ses:us-east-1:${local.aws_account_id}:identity/${local.vars.ENV}.gildarck.com"
  email_from_address    = "no-reply@${local.vars.ENV}.gildarck.com"

  tags = local.tags
}