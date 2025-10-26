
locals {
  environment = "dev"
  owner_vars  = read_terragrunt_config(find_in_parent_folders("owner.hcl"))
  tags        = merge(local.owner_vars.locals.tags, { environment = local.environment })
  #VARIABLES
  ENV = "dev"
  /* --------------------------- Amplify vars start --------------------------- */
  AMPLIFY_GIT_TOKEN   = get_env("GIT_TOKEN_AMPLIFY_GILDARCK")
  AMPLIFY_GIT_SOURCE  = "https://github.com/jhoammoralesc/frontend-main-front.git"
  AMPLIFY_CREDENTIALS = base64encode("devUser:${get_env("DEV_AMPLIFY_BASIC_AUTH_PASS")}")
  AMPLIFY_BRANCH      = "develop"
  AMPLIFY_DNS         = "dev.gildarck.com"
  AMPLIFY_VARIABLES = {
    DOMAIN            = "https://dev.gildarck.com/"
    API_URL_BASE      = "https://gslxbu791e.execute-api.us-east-1.amazonaws.com/dev"
    URL_BASE_IMAGES   = "https://assets.dev.gildarck.com"
    SUPPORT_EMAIL     = "maohjmorales91@gmail.com"
    DOWNTIME          = 8
    ENVIRONMENT       = "dev"

  }
  /* ---------------------------- Amplify vars end ---------------------------- */
  /* --------------------------- Amplify backoffice vars start --------------------------- */
  AMPLIFY_BO_GIT_TOKEN   = get_env("GIT_TOKEN")
  AMPLIFY_BO_GIT_SOURCE  = "https://github.com/gildarck/frontend-backoffice"
  AMPLIFY_BO_CREDENTIALS = base64encode("devUser:${get_env("DEV_AMPLIFY_BASIC_AUTH_PASS")}")
  AMPLIFY_BO_BRANCH      = "develop"
  AMPLIFY_BO_DNS         = "bo.dev.gildarck.com"

  AMPLIFY_BO_VARIABLES = {
    ENVIRONMENT              = "dev"
    API_URL_BASE             = "https://api.bo.dev.gildarck.com/"
    REQUEST_TIMEOUT          = "10000"
    AMPLYFY_USER_POOL_ID     = "us-east-1_QgxcR8eel"
    AMPLIFY_USER_POOL_CLIENT = get_env("AMPLIFY_BO_USER_POOL_CLIENT")
    AMPLIFY_DOMAIN           = "backoffice-user-pool.auth.us-east-1.amazoncognito.com"
    AMPLIFY_SCOPE            = "openid,aws.cognito.signin.user.admin"
    AMPLIFY_REDIRECTION      = "https://bo.dev.gildarck.com"
    AMPLYFY_RESPONSE_TYPE    = "code"
    AMPLYFY_CUSTOM_PROVIDER  = "SSO"
    URL_PLATFORM             = "https://dev.gildarck.com/"
    URL_BASE_IMAGES          = "https://assets.dev.gildarck.com"
    MAX_EXPORTATION_ELEMENTS = "100"
  }
  /* ---------------------------- Amplify backoffice vars end ---------------------------- */
  /* --------------------------- Amplify Self Management Portal vars start --------------------------- */
  AMPLIFY_APIM_GIT_TOKEN  = get_env("GIT_TOKEN")
  AMPLIFY_APIM_GIT_SOURCE = "https://github.com/gildarck/frontend-self-service-portal"
  AMPLIFY_APIM_DNS        = "portal.apim.dev.gildarck.com"
  AMPLIFY_APIM_VARIABLES = {
    AMPLIFY_USERPOOL_ID  = "us-east-1_SqRB9UaHj"
    AMPLIFY_WEBCLIENT_ID = "454qelaoerh3efnhi356a3n04f"
    PRODUCT_NAME         = "Api Manager"
    BASE_URL_APIM        = "https://apim.dev.gildarck.com"
    ENV                  = "dev"
  }
  /* ---------------------------- Amplify Self Management Portal vars end ---------------------------- */

  /* --------------------------- Amplify payments form vars start --------------------------- */
  AMPLIFY_PAYMENT_FORM_GIT_TOKEN  = get_env("GIT_TOKEN")
  AMPLIFY_PAYMENT_FORM_GIT_SOURCE = "https://github.com/gildarck/frontend-flexibility-pagos"
  AMPLIFY_PAYMENT_FORM_DNS        = "payments-form.dev.gildarck.com"
  AMPLIFY_PAYMENT_FORM_VARIABLES = {
    VITE_PROVIDER_URL            = "https://developers.decidir.com/api/v2/"
    VITE_PROVIDER_API_KEY        = get_env("DEV_AMPLIFY_PAYMENT_FORM_API_KEY")
    VITE_DEFAULT_BACK_URL        = "https://dev.gildarck.com"
    VITE_BACKEND_BASE_URL        = "https://api.flexi.dev.gildarck.com/payment-manager"
    VITE_FEATURE_FLAG_AGRO_TOKEN = true
  }
  /* ---------------------------- Amplify payments form vars end ---------------------------- */

  /* --------------------------- Amplify chat form vars start --------------------------- */
  AMPLIFY_CHAT_gildarck_GIT_TOKEN  = get_env("GIT_TOKEN")
  AMPLIFY_CHAT_gildarck_GIT_SOURCE = "https://github.com/gildarck/frontend-gildarck-chat-web-client"
  AMPLIFY_CHAT_gildarck_DNS        = "chat.dev.gildarck.com"
  AMPLIFY_CHAT_gildarck_VARIABLES = {
    VITE_SERVER_URL = "https://synapse.dev.gildarck.com"
  }
  /* ---------------------------- Amplify chat form vars end ---------------------------- */

  /* --------------------------- COGNITO vars start --------------------------- */
  COGNITO_USER_POOL_NAME = "gildarck-user-pool"
  COGNITO_DOMAIN_PREFIX  = "gildarck-auth"
  /* ---------------------------- COGNITO vars end ---------------------------- */

  /* ------------------------- Api Gateway vars start ------------------------- */
  AGW_PRIVATE_LINK_TARGETS = ["arn:aws:elasticloadbalancing:us-east-1:559756754086:loadbalancer/net/a0f15b6056ef44545993d99cc5f1b38e/bff40da06b806282"]
  /* -------------------------- Api Gateway vars end -------------------------- */
  /* ---------------------- Lambda Authorizer vars start ---------------------- */
  AUDIENCE = "gildarckdes"
  /* ----------------------- Lambda Authorizer vars end ----------------------- */
  /* -------------------------- MySQL core vars start ------------------------- */
  MYSQL_CORE_USERNAME = "gildarck_db"
  MYSQL_CORE_PASSWORD = get_env("DEV_MYSQL_CORE_PASSWORD")
  /* --------------------------- MySQL core vars end -------------------------- */
  /* --------------------------- MySQL fm vars start -------------------------- */
  MYSQL_FM_USERNAME = "gildarck_db_2"
  MYSQL_FM_PASSWORD = get_env("DEV_MYSQL_FM_PASSWORD")
  /* ---------------------------- MySQL fm vars end --------------------------- */
  /* ---------------------- MySQL flexibility vars start ---------------------- */
  MYSQL_FLEXIBILITY_USERNAME = "flexibility"
  MYSQL_FLEXIBILITY_PASSWORD = get_env("MYSQL_FLEXIBILITY_PASSWORD")
  /* ----------------------- MySQL flexibility vars end ----------------------- */
  /* ---------------------- MySQL speedboat-ia vars start ---------------------- */
  MYSQL_IA_USERNAME = "speedboatia"
  MYSQL_IA_PASSWORD = get_env("DEV_MYSQL_IA_PASSWORD")
  /* ----------------------- MySQL fspeedboat-ia vars end ----------------------- */
  /* ---------------------- PostgreSQL chat empresarial vars start ---------------------- */
  POSTGRESQL_CHAT_USERNAME = "chatempresarial"
  POSTGRESQL_CHAT_PASSWORD = get_env("DEV_POSTGRESQL_CHAT_PASSWORD")
  /* ----------------------- PostgreSQL chat empresarial vars end ----------------------- */
  /* --------------------------- Route53 vars start --------------------------- */
  HOSTED_ZONE_NAME = "dev.gildarck.com"
  /* ---------------------------- Route53 vars end ---------------------------- */
  /* ----------------------------- VPC vars start ----------------------------- */
  CIDR                     = "10.0.0.0/16"
  AZS                      = ["us-east-1a", "us-east-1b", "us-east-1c"]
  PRIVATE_SUBNETS          = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  PUBLIC_SUBNETS           = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  DATABASE_SUBNETS         = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  ENABLE_NAT_GATEWAY       = false
  ENABLE_INTERNET_GATEWAY  = true
  SINGLE_NAT_GATEWAY       = false
  ONE_NAT_GATEWAY_PER_AZ   = false
  ENABLE_DNS_HOSTNAMES     = true
  ENABLE_DNS_SUPPORT       = true
  /* ------------------------------ VPC vars end ------------------------------ */
}