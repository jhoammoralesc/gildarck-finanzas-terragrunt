# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# We override the terraform block source attribute here just for the QA environment to show how you would deploy a
# different version of the module in a specific environment.
terraform {
  source = include.envcommon.locals.base_source_url
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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/apigateway/vpclink-api.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "k8s.${local.vars.ENV}.gildarck.com"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
  vpc_link_id  = "y38ap6"
  responseParameters = {
    "method.response.header.Content-Type"                 = "integration.response.header.Content-Type"
    "method.response.header.Content-Disposition"          = "integration.response.header.Content-Disposition"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type,lang,mac-address,ip-address,version,out_url'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,DELETE,PATCH,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  headers = {

    "Content-Type" = {
      "type" = "string"
    }

    "Content-Disposition" = {
      "type" = "string"
    }

    "Access-Control-Allow-Headers" = {
      "type" = "string"
    }

    "Access-Control-Allow-Methods" = {
      "type" = "string"
    }

    "Access-Control-Allow-Origin" = {
      "type" = "string"
    }
  }
  integration_responses = {

    200 = {
      statusCode         = 200
      responseParameters = local.responseParameters
    }

    202 = {
      statusCode         = 202
      responseParameters = local.responseParameters
    }

    201 = {
      statusCode         = 201
      responseParameters = local.responseParameters
    }

    301 = {
      statusCode         = 301
      responseParameters = local.responseParameters
    }

    400 = {
      statusCode         = 400
      responseParameters = local.responseParameters

    }

    401 = {
      statusCode         = 401
      responseParameters = local.responseParameters

    }

    403 = {
      statusCode         = 403
      responseParameters = local.responseParameters
    }

    404 = {
      statusCode         = 404
      responseParameters = local.responseParameters
    }

    409 = {
      statusCode         = 409
      responseParameters = local.responseParameters
    }

    422 = {
      statusCode         = 422
      responseParameters = local.responseParameters
    }

    500 = {
      statusCode         = 500
      responseParameters = local.responseParameters
    }

    501 = {
      statusCode         = 501
      responseParameters = local.responseParameters
    }

    502 = {
      statusCode         = 502
      responseParameters = local.responseParameters
    }
  }

  responses = {

    200 = {
      description = "200 response"
      headers     = local.headers
    }

    201 = {
      description = "201 response"
      headers     = local.headers
    }

    202 = {
      description = "202 response"
      headers     = local.headers
    }

    301 = {
      description = "301 response"
      headers     = local.headers
    }

    400 = {
      description = "400 response"
      headers     = local.headers
    }

    401 = {
      description = "401 response"
      headers     = local.headers
    }

    403 = {
      description = "403 response"
      headers     = local.headers
    }

    404 = {
      description = "404 response"
      headers     = local.headers
    }

    409 = {
      description = "409 response"
      headers     = local.headers
    }

    422 = {
      description = "422 response"
      headers     = local.headers
    }

    500 = {
      description = "500 response"
      headers     = local.headers
    }

    501 = {
      description = "501 response"
      headers     = local.headers
    }

    502 = {
      description = "502 response"
      headers     = local.headers
    }
  }

  options = {
    consumes = ["application/json"]
    x-amazon-apigateway-integration = {
      type = "MOCK"
      requestTemplates = {
        "application/json" = "{\"statusCode\": 200}"
      }
      responses           = local.integration_responses
      passthroughBehavior = "WHEN_NO_MATCH"
    }

    responses = local.responses
  }

}

dependencies {
  paths = [
    "../../route53/zones/${local.vars.ENV}.gildarck.com"
  ]
}

dependency "domain" {
  config_path = "../../route53/zones/${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

generate "vars" {
  path      = "variables.auto.tfvars"
  if_exists = "overwrite"
  contents = <<-EOT
    openapi_config = ${jsonencode({
  openapi = "3.0.1"

  info = {
    title       = local.name
    version     = "1.0"
    description = "API (BFF) con todos los endpoints para acceder a la carga de trabajo de intercobros usados por la plataforma."
  }

  components = {
    securitySchemes = {
      FirebaseJWTAuthorizer = {
        type                         = "apiKey"
        name                         = "Authorization"
        in                           = "header"
        x-amazon-apigateway-authtype = "custom"
        x-amazon-apigateway-authorizer = {
          type                         = "request"
          authorizerUri                = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:559756754086:function:function-authorizer/invocations"
          authorizerResultTtlInSeconds = 0
          identitySource               = "method.request.header.Authorization"
        }
      }
    }
  }

  paths = {

    "/platform/v1/account/login" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/login"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/sign-in" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/sign-in"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

      }

      options = local.options
    }

    "/platform/v1/account/refresh-token" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/refresh-token"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/logout" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/logout"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/password-verify" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/password-verify"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.key"        = "method.request.querystring.key"
            "integration.request.querystring.oobCode"    = "method.request.querystring.oobCode"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "key",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "oobCode",
            in       = "query",
            required = true,
            type     = "string"
          },
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/dashboard/summary" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/dashboard/summary"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.filter-by"  = "method.request.querystring.filter-by"
            "integration.request.querystring.date-range" = "method.request.querystring.date-range"
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "filter-by",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "date-range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options
    }

    "/platform/v1/payments/notify" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/notify"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "query",
            required = false,
            type     = "string"
          },
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/sso/redirect" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/sso/redirect"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.provider" = "method.request.querystring.provider"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "provider",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/sso/login" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/sso/login"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
        }

        responses = local.responses

      }
      options = local.options
    }

    "/platform/v1/accounts" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/accounts"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "company-id",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/availability" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/availability"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.User-Timezone"   = "method.request.querystring.user-timezone"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "user-timezone",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/register/content" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/content"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.code"       = "method.request.querystring.code"
            "integration.request.querystring.lang"       = "method.request.querystring.lang"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "code",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "lang",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/register/content/{id}/{version}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/content/{id}/{version}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.path.version"           = "method.request.path.version"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "version",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/content/terms-and-conditions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/content/terms-and-conditions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/profile" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/profile"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/platform/v1/permissions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/permissions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/platform/v1/profile/{profile-id}/permissions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/profile/{profile-id}/permissions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.profile-id"        = "method.request.path.profile-id"
            "integration.request.querystring.company_id" = "method.request.querystring.company_id"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "profile-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "company_id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/platform/v1/persons/status" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/status"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/platform/v1/persons" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/platform/v1/persons/reset-password" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/reset-password"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/persons" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }

        parameters = [{
          name     = "Authorization",
          in       = "header",
          required = false,
          type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options


    }

    "/platform/v1/persons/lang" = {
      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/lang"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"

          requestParameters = {
            "integration.request.querystring.lang"       = "method.request.querystring.lang"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "lang"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/persons/email/{email}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/email/{email}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.email"             = "method.request.path.email"
            "integration.request.header.Authorization"   = "context.authorizer.token"

          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "email",
            in       = "path",
            required = true,
            schema = {
              type = "string"
            }
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/platform/v1/persons/profile" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/profile"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/companies" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/companies/add-user" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/add-user"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/companies/my-company" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/invitations" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/invitations/pending" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations/pending"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.email"      = "method.request.querystring.email"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "email",
            in       = "query",
            required = true,
            schema = {
              type = "string"
            }
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/invitations/company-exists" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations/company-exists"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"      = "method.request.header.Accept-Language"
            "integration.request.querystring.document-type"   = "method.request.querystring.document-type"
            "integration.request.querystring.document-number" = "method.request.querystring.document-number"
            "integration.request.header.Authorization"        = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "document-type",
            in       = "query",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "document-number",
            in       = "query",
            required = true,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/invitations/{invitation-id}" = {
      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations/{invitation-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.invitation-id"     = "method.request.path.invitation-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "invitation-id",
            in       = "path",
            required = true,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations/{invitation-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.invitation-id"     = "method.request.path.invitation-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "invitation-id",
            in       = "path",
            required = true,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/invitations/upload" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations/upload"
          responses = {
            "200" : {
              "statusCode" : "200",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "400" : {
              "statusCode" : "400",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "422" : {
              "statusCode" : "422",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "500" : {
              "statusCode" : "500",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            }
          }

          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept"          = "'*/*'",
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type",
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  file = {
                    type   = "string",
                    format = "binary"
                  }
                }
              }
            }
          }
        }
      }
      options = local.options
    }

    "/platform/v1/invitations/download/example" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/invitations/download/example"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/integrations/payment-files" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/integrations/payment-files"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.querystring.sort"       = "method.request.querystring.sort"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "page"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/integrations/payment-files"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [{
          name     = "Authorization",
          in       = "header",
          required = false,
          type     = "string"
        }]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/integrations/payment-files/{numero_lote}/errors" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/integrations/payment-files/{numero_lote}/errors"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"

          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.numero_lote"       = "method.request.path.numero_lote"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }



    "/platform/v1/payments/payment" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/status"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/detail/{paymentId}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/detail/{paymentId}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.paymentId"         = "method.request.path.paymentId"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "paymentId",
            in       = "path",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payer" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payer"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.page"                 = "method.request.querystring.page"
            "integration.request.querystring.size"                 = "method.request.querystring.size"
            "integration.request.querystring.sort"                 = "method.request.querystring.sort"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.payment-id"           = "method.request.querystring.payment-id"
            "integration.request.querystring.payment-type"         = "method.request.querystring.payment-type"
            "integration.request.querystring.payment-method-id"    = "method.request.querystring.payment-method-id"
            "integration.request.querystring.network-number"       = "method.request.querystring.network-number"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.bank-network-number"  = "method.request.querystring.bank-network-number"
            "integration.request.querystring.applied"              = "method.request.querystring.applied"
            "integration.request.querystring.entities"             = "method.request.querystring.entities"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
          requestTemplates = {
            "application/json" = <<EOF
            #set($allParams = $input.params())
            {
              "params": {
                #foreach($type in $allParams.keySet())
                #set($params = $allParams.get($type))
                "$type": {
                  #foreach($paramName in $params.keySet())
                  #if($paramName == "transaction-number" || $paramName == "check-number" || $paramName == "operation-number" || $paramName == "echeq-number" || $paramName == "transfer-number")
                    #if($util.escapeJavaScript($params.get($paramName)) != "")
                      #set($context.requestOverride.querystring.transaction-number = $util.escapeJavaScript($params.get($paramName)))
                      #break
                    #end
                  #end
                  "$paramName": "$util.escapeJavaScript($params.get($paramName))"#if($foreach.hasNext),#end
                  #end
                }#if($foreach.hasNext),#end
                #end
              }
            }
            EOF
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-method-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "network-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "collector-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "bank-network-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "applied"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "transaction-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "check-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "operation-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "echeq-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "transfer-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "entities"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payer/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payer/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.transaction-number"   = "method.request.querystring.transaction-number"
            "integration.request.querystring.payment-id"           = "method.request.querystring.payment-id"
            "integration.request.querystring.payment-type"         = "method.request.querystring.payment-type"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.lang"                 = "method.request.querystring.lang"
            "integration.request.querystring.offline"              = "method.request.querystring.offline"
            "integration.request.querystring.entities"             = "method.request.querystring.entities"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "transaction-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "collector-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lang"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "entities"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payer/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payer/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"   = "method.request.header.Accept-Language"
            "integration.request.path.id"                  = "method.request.path.id"
            "integration.request.querystring.payment-type" = "method.request.querystring.payment-type"
            "integration.request.querystring.mode"         = "method.request.querystring.mode"
            "integration.request.header.Authorization"     = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id"
            in       = "path"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name         = "mode"
            in           = "query"
            required     = false
            defaultValue = "inside"
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    ## ELIMINAR INICIO
    "/platform/v1/payments/my-payers" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/my-payers"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.querystring.sort"       = "method.request.querystring.sort"
            "integration.request.querystring.id"         = "method.request.querystring.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/my-payers/filter/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/my-payers/filter/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }
    ## ELIMINAR FINAL

    "/platform/v1/payments/my-clients/filter/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/my-clients/filter/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/my-clients" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/my-clients"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"      = "method.request.header.Accept-Language"
            "integration.request.querystring.document_number" = "method.request.querystring.document_number"
            "integration.request.querystring.status"          = "method.request.querystring.status"
            "integration.request.querystring.page"            = "method.request.querystring.page"
            "integration.request.querystring.size"            = "method.request.querystring.size"
            "integration.request.querystring.sort"            = "method.request.querystring.sort"
            "integration.request.querystring.id"              = "method.request.querystring.id"
            "integration.request.header.Authorization"        = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "document_number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/my-clients"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  file = {
                    type   = "string",
                    format = "binary"
                  }
                }
              }
            }
          }
        }

      }



      options = local.options
    }

    "/platform/v1/payments/payment/generated" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment/generated"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"       = "method.request.header.Accept-Language"
            "integration.request.querystring.payment_order_id" = "method.request.querystring.payment_order_id"
            "integration.request.querystring.payment_id"       = "method.request.querystring.payment_id"
            "integration.request.header.Authorization"         = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment_id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
            }, {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-methods" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-methods"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-methods/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-methods/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/request-payment/{request_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/request-payment/{request_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.request_id"        = "method.request.path.request_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"              = "method.request.header.Accept-Language"
            "integration.request.header.version"                      = "method.request.header.version"
            "integration.request.querystring.collector-company-id"    = "method.request.querystring.collector-company-id"
            "integration.request.querystring.payment-to-debt-allowed" = "method.request.querystring.payment-to-debt-allowed"
            "integration.request.path.payment_order_id"               = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"                = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "version",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "collector-company-id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-to-debt-allowed"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/send" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/send"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/retry-payment" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/retry-payment"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/previous/internal" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/previous/internal"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/{payment_method_code}" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/{payment_method_code}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.payment_order_id"    = "method.request.path.payment_order_id"
            "integration.request.path.payment_method_code" = "method.request.path.payment_method_code"
            "integration.request.header.Authorization"     = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment_method_code",
            in       = "path",
            required = true,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/{payment_method_code}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.payment_order_id"    = "method.request.path.payment_order_id"
            "integration.request.path.payment_method_code" = "method.request.path.payment_method_code"
            "integration.request.header.Authorization"     = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment_method_code",
            in       = "path",
            required = true,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/b2b" = {
      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/b2b"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.payment_order_id" = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"  = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/resume" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/resume"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.querystring.sort"       = "method.request.querystring.sort"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "company-id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/footer" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/footer"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.payment_order_id" = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"  = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/informed/{informed_pay_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/informed/{informed_pay_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization"             = "context.authorizer.token"
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"            = "method.request.path.payment_order_id"
            "integration.request.path.informed_pay_id"             = "method.request.path.informed_pay_id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "informed_pay_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/informed/{informed_pay_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.path.informed_pay_id"   = "method.request.path.informed_pay_id"
            "integration.request.header.Accept"          = "'*/*'"
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "informed_pay_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  payment_voucher = {
                    type   = "string",
                    format = "binary"
                  },
                  payment_request = {
                    type = "string"
                  }
                }
              }
            }
          }
        }
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/informed/{informed_pay_id}/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/informed/{informed_pay_id}/download"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.path.informed_pay_id"   = "method.request.path.informed_pay_id"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "informed_pay_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/reserve-id/{company_id}" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/reserve-id/{company_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.company_id"      = "method.request.path.company_id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "company_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/previous" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/previous"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.payment_order_id" = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"  = "context.authorizer.token"
            "integration.request.querystring.type"      = "method.request.querystring.type"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "type",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.header.version"                   = "method.request.header.version"
            "integration.request.querystring.date-range"           = "method.request.querystring.date-range"
            "integration.request.querystring.page"                 = "method.request.querystring.page"
            "integration.request.querystring.size"                 = "method.request.querystring.size"
            "integration.request.querystring.sort"                 = "method.request.querystring.sort"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.payment-order-id"     = "method.request.querystring.payment-order-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "version",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "date-range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-order-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/documents" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/documents"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payment-order-id" = "method.request.querystring.payment-order-id"
            "integration.request.header.Authorization"         = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment-order-id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/payments/payment-order/documents/{document_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/documents/{document_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.document_id"     = "method.request.path.document_id"
            "integration.request.querystring.view"     = "method.request.querystring.view"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "document_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "view"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/documents/{document_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.document_id"     = "method.request.path.document_id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "document_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/documents/parcial-payment" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/documents/parcial-payment"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/payments/payment-order/add-documents" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/add-documents"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/payments/payment-order/documents/{document_id}/{payment_order_id}" = {
      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/documents/{document_id}/{payment_order_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.document_id"      = "method.request.path.document_id"
            "integration.request.path.payment_order_id" = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"  = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "document_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/payments/payment-order/payment" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/payment"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/payments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/payments"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/payments/{payment_id}" = {
      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/payments/{payment_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.path.payment_id"        = "method.request.path.payment_id"
            "integration.request.querystring.type"       = "method.request.querystring.type"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "type",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/customize" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/customize"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/customize"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/export"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.date-range"           = "method.request.querystring.date-range"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.payment-order-id"     = "method.request.querystring.payment-order-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "date-from",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "date-to",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "date-range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "array",
            items = {
              type = "number"
            }
          },
          {
            name     = "payment-order-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/dashboard/status-summary" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/dashboard/status-summary"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.date-range" = "method.request.querystring.date-range"
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "date-range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options
    }

    "/platform/v1/payments/collector-payment-order/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/collector-payment-order/export"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.date-from"        = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"          = "method.request.querystring.date-to"
            "integration.request.querystring.date-range"       = "method.request.querystring.date-range"
            "integration.request.querystring.status"           = "method.request.querystring.status"
            "integration.request.querystring.payment-order-id" = "method.request.querystring.payment-order-id"
            "integration.request.querystring.payer-company-id" = "method.request.querystring.payer-company-id"
            "integration.request.header.Authorization"         = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "date-from",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "date-to",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "date-range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "array",
            items = {
              type = "number"
            }
          },
          {
            name     = "payment-order-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "payer-company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }


    "/platform/v1/payments/previous/echeqs" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/previous/echeqs"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.available"             = "method.request.querystring.available"
            "integration.request.querystring.amount-from"           = "method.request.querystring.amount-from"
            "integration.request.querystring.amount-to"             = "method.request.querystring.amount-to"
            "integration.request.querystring.collector-company-id"  = "method.request.querystring.collector-company-id"
            "integration.request.querystring.date-from"             = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"               = "method.request.querystring.date-to"
            "integration.request.querystring.echeq-id"              = "method.request.querystring.echeq-id"
            "integration.request.querystring.echeq-status"          = "method.request.querystring.echeq-status"
            "integration.request.querystring.echeq-number"          = "method.request.querystring.echeq-number"
            "integration.request.querystring.issue-date-from"       = "method.request.querystring.issue-date-from"
            "integration.request.querystring.issue-date-to"         = "method.request.querystring.issue-date-to"
            "integration.request.querystring.payer-document-number" = "method.request.querystring.payer-document-number"
            "integration.request.querystring.page"                  = "method.request.querystring.page"
            "integration.request.querystring.size"                  = "method.request.querystring.size"
            "integration.request.querystring.sort"                  = "method.request.querystring.sort"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.from-payment-order"    = "method.request.querystring.from-payment-order"
            "integration.request.header.Authorization"              = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "available",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "amount-from",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "amount-to",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "date-from",
            in       = "query",
            required = true,
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to",
            in       = "query",
            required = true,
            schema = {
              type = "string"
            }
          },
          {
            name     = "echeq-id",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "echeq-status",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "echeq-number",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "issue-date-from",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "issue-date-to",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-document-number",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "page",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "days",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "from-payment-order",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/previous/echeqs/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/previous/echeqs/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-document-number" = "method.request.querystring.payer-document-number"
            "integration.request.querystring.date-from"             = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"               = "method.request.querystring.date-to"
            "integration.request.querystring.issue-date-from"       = "method.request.querystring.issue-date-from"
            "integration.request.querystring.issue-date-to"         = "method.request.querystring.issue-date-to"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.echeq-id"              = "method.request.querystring.echeq-id"
            "integration.request.querystring.echeq-number"          = "method.request.querystring.echeq-number"
            "integration.request.querystring.echeq-status"          = "method.request.querystring.echeq-status"
            "integration.request.querystring.available"             = "method.request.querystring.available"
            "integration.request.querystring.amount-from"           = "method.request.querystring.amount-from"
            "integration.request.querystring.amount-to"             = "method.request.querystring.amount-to"
            "integration.request.querystring.offline"               = "method.request.querystring.offline"
            "integration.request.header.Authorization"              = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-document-number",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-from",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "issue-date-from",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "issue-date-to",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "days",
            in       = "query",
            required = false,
            schema = {
              type    = "number",
              default = 90
            }
          },
          {
            name     = "echeq-id",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "echeq-number",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "echeq-status",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "available",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "amount-from",
            in       = "query",
            required = false,
            schema = {
              type   = "number",
              format = "decimal"
            }
          },
          {
            name     = "amount-to",
            in       = "query",
            required = false,
            schema = {
              type   = "number",
              format = "decimal"
            }
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/previous/movements" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/previous/movements"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.available"             = "method.request.querystring.available"
            "integration.request.querystring.amount-from"           = "method.request.querystring.amount-from"
            "integration.request.querystring.amount-to"             = "method.request.querystring.amount-to"
            "integration.request.querystring.collector-company-id"  = "method.request.querystring.collector-company-id"
            "integration.request.querystring.date-from"             = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"               = "method.request.querystring.date-to"
            "integration.request.querystring.description"           = "method.request.querystring.description"
            "integration.request.querystring.account-number"        = "method.request.querystring.account-number"
            "integration.request.querystring.bank-code"             = "method.request.querystring.bank-code"
            "integration.request.querystring.transaction"           = "method.request.querystring.transaction"
            "integration.request.querystring.payer-document-number" = "method.request.querystring.payer-document-number"
            "integration.request.querystring.page"                  = "method.request.querystring.page"
            "integration.request.querystring.size"                  = "method.request.querystring.size"
            "integration.request.querystring.sort"                  = "method.request.querystring.sort"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.from-payment-order"    = "method.request.querystring.from-payment-order"
            "integration.request.header.Authorization"              = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "available",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "amount-from",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "amount-to",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "date-from",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "description",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "account-number",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "bank-code",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "transaction",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-document-number",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "page",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "days",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "from-payment-order",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/previous/movements/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/previous/movements/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.id"                    = "method.request.path.id"
            "integration.request.querystring.linked_payment" = "method.request.querystring.linked_payment"
            "integration.request.header.Authorization"       = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "id",
            in       = "path",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "linked_payment",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/previous/movements/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/previous/movements/export"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-document-number" = "method.request.querystring.payer-document-number"
            "integration.request.querystring.description"           = "method.request.querystring.description"
            "integration.request.querystring.bank-code"             = "method.request.querystring.bank-code"
            "integration.request.querystring.account-number"        = "method.request.querystring.account-number"
            "integration.request.querystring.date-from"             = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"               = "method.request.querystring.date-to"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.transaction"           = "method.request.querystring.transaction"
            "integration.request.querystring.available"             = "method.request.querystring.available"
            "integration.request.querystring.amount-from"           = "method.request.querystring.amount-from"
            "integration.request.querystring.amount-to"             = "method.request.querystring.amount-to"
            "integration.request.querystring.offline"               = "method.request.querystring.offline"
            "integration.request.header.Authorization"              = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-document-number"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "description"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "bank-code"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "account-number"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "days"
            in       = "query"
            required = false
            type     = "integer"
            format   = "int64"
          },
          {
            name     = "transaction"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "available"
            in       = "query"
            required = false
            type     = "boolean"
          },
          {
            name     = "amount-from"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "amount-to"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "offline"
            in       = "query"
            required = false
            type     = "boolean"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/deductions/adjustments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/adjustments"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.size"               = "method.request.querystring.size",
            "integration.request.querystring.sort"               = "method.request.querystring.sort",
            "integration.request.querystring.page"               = "method.request.querystring.page",
            "integration.request.querystring.view"               = "method.request.querystring.view"
            "integration.request.querystring.payer-company-id"   = "method.request.querystring.payer-company-id"
            "integration.request.querystring.concept"            = "method.request.querystring.concept"
            "integration.request.querystring.status"             = "method.request.querystring.status",
            "integration.request.querystring.currency"           = "method.request.querystring.currency"
            "integration.request.querystring.min-amount"         = "method.request.querystring.min-amount"
            "integration.request.querystring.max-amount"         = "method.request.querystring.max-amount"
            "integration.request.querystring.creation-date-from" = "method.request.querystring.creation-date-from"
            "integration.request.querystring.creation-date-to"   = "method.request.querystring.creation-date-to"
            "integration.request.querystring.id"                 = "method.request.querystring.id"
            "integration.request.querystring.payment-order-id"   = "method.request.querystring.payment-order-id"
            "integration.request.querystring.days"               = "method.request.querystring.days"
            "integration.request.header.Authorization"           = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "sort",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "page",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "view"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-company-id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "concept",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "currency",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "min-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "max-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "creation-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "creation-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "payment-order-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "days",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/dates/resolve" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/dates/resolve"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.days"          = "method.request.querystring.days"
            "integration.request.querystring.business-days" = "method.request.querystring.business-days"
            "integration.request.querystring.date-from"     = "method.request.querystring.date-from"
            "integration.request.querystring.country-id"    = "method.request.querystring.country-id"
            "integration.request.header.Authorization"      = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "days",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "business-days",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "country-id",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/deductions/adjustments/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/adjustments/export"
          responses            = local.integration_responses

          requestParameters = {
            "integration.request.querystring.payer-company-id"   = "method.request.querystring.payer-company-id"
            "integration.request.querystring.concept"            = "method.request.querystring.concept"
            "integration.request.querystring.status"             = "method.request.querystring.status",
            "integration.request.querystring.currency"           = "method.request.querystring.currency"
            "integration.request.querystring.min-amount"         = "method.request.querystring.min-amount"
            "integration.request.querystring.max-amount"         = "method.request.querystring.max-amount"
            "integration.request.querystring.creation-date-from" = "method.request.querystring.creation-date-from"
            "integration.request.querystring.creation-date-to"   = "method.request.querystring.creation-date-to"
            "integration.request.querystring.id"                 = "method.request.querystring.id"
            "integration.request.querystring.payment-order-id"   = "method.request.querystring.payment-order-id"
            "integration.request.querystring.days"               = "method.request.querystring.days"
            "integration.request.querystring.view"               = "method.request.querystring.view"
            "integration.request.querystring.offline"            = "method.request.querystring.offline"
            "integration.request.header.Authorization"           = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "concept",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "currency",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "min-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "max-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "creation-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "creation-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "payment-order-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "days",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "view"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/deductions/payment-order/{payment-order-id}/retentions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/payment-order/{payment-order-id}/retentions"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment-order-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/payment-order/{payment-order-id}/retentions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept"          = "'*/*'",
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id"
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type",
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-order-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  retention_file = {
                    type   = "string",
                    format = "binary"
                  },
                  retention_data = {
                    type = "string"
                  }
                }
              }
            }
          }
        }
      }

      options = local.options
    }

    "/platform/v1/deductions/payment-order/{payment-order-id}/retentions/{retention-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/payment-order/{payment-order-id}/retentions/{retention-id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id"
            "integration.request.path.retention-id"      = "method.request.path.retention-id"
            "integration.request.querystring.edition"    = "method.request.querystring.edition"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment-order-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "retention-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "edition",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/payment-order/{payment-order-id}/retentions/{retention-id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id"
            "integration.request.path.retention-id"      = "method.request.path.retention-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept"          = "'*/*'",
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type",
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-order-id",
            in       = "path",
            required = true,
            type     = "string"
          },
          {
            name     = "retention-id",
            in       = "path",
            required = true,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  retention_file = {
                    type   = "string",
                    format = "binary"
                  },
                  retention_data = {
                    type = "string"
                  }
                }
              }
            }
          }
        }

      }

      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/payment-order/{payment-order-id}/retentions/{retention-id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id"
            "integration.request.path.retention-id"      = "method.request.path.retention-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-order-id",
            in       = "path",
            required = true,
            type     = "string"
          },
          {
            name     = "retention-id",
            in       = "path",
            required = true,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/deductions/payment-order/{payment-order-id}/retentions/{retention-id}/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/payment-order/{payment-order-id}/retentions/{retention-id}/download"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id"
            "integration.request.path.retention-id"      = "method.request.path.retention-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment-order-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "retention-id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents/dashboard/account-statements/expiration" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/dashboard/account-statements/expiration"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.querystring.view"       = "method.request.querystring.view"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "view",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents/dashboard/account-statements" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/dashboard/account-statements"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.size"                    = "method.request.querystring.size",
            "integration.request.querystring.sort"                    = "method.request.querystring.sort",
            "integration.request.querystring.page"                    = "method.request.querystring.page",
            "integration.request.querystring.status"                  = "method.request.querystring.status",
            "integration.request.querystring.receipt_type"            = "method.request.querystring.receipt_type",
            "integration.request.querystring.due_date_ini"            = "method.request.querystring.due_date_ini",
            "integration.request.querystring.due_date_end"            = "method.request.querystring.due_date_end",
            "integration.request.querystring.due_date_range"          = "method.request.querystring.due_date_range"
            "integration.request.querystring.pub_date_ini"            = "method.request.querystring.pub_date_ini",
            "integration.request.querystring.pub_date_end"            = "method.request.querystring.pub_date_end",
            "integration.request.querystring.days"                    = "method.request.querystring.days",
            "integration.request.querystring.collector_company_id"    = "method.request.querystring.collector_company_id",
            "integration.request.querystring.receipt_number"          = "method.request.querystring.receipt_number",
            "integration.request.querystring.legal_ref"               = "method.request.querystring.legal_ref",
            "integration.request.querystring.id_1"                    = "method.request.querystring.id_1",
            "integration.request.querystring.payer_company_id"        = "method.request.querystring.payer_company_id",
            "integration.request.querystring.linked_to_payment_order" = "method.request.querystring.linked_to_payment_order",
            "integration.request.querystring.view"                    = "method.request.querystring.view"
            "integration.request.querystring.from_payment_order"      = "method.request.querystring.from_payment_order",
            "integration.request.header.Authorization"                = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "sort",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "page",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "receipt_type",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "pub_date_ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub_date_end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "days",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "collector_company_id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "receipt_number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "legal_ref",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "id_1",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "payer_company_id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "linked_to_payment_order",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "view",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "from_payment_order",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]


      }

      options = local.options
    }

    "/platform/v1/documents/collector/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/collector/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.status"                  = "method.request.querystring.status",
            "integration.request.querystring.due_date_ini"            = "method.request.querystring.due_date_ini",
            "integration.request.querystring.due_date_end"            = "method.request.querystring.due_date_end",
            "integration.request.querystring.pub_date_ini"            = "method.request.querystring.pub_date_ini",
            "integration.request.querystring.pub_date_end"            = "method.request.querystring.pub_date_end",
            "integration.request.querystring.payer_company_id"        = "method.request.querystring.payer_company_id",
            "integration.request.querystring.receipt_number"          = "method.request.querystring.receipt_number",
            "integration.request.querystring.legal_ref"               = "method.request.querystring.legal_ref",
            "integration.request.querystring.linked_to_payment_order" = "method.request.querystring.linked_to_payment_order",
            "integration.request.querystring.id_1"                    = "method.request.querystring.id_1",
            "integration.request.querystring.offline"                 = "method.request.querystring.offline",
            "integration.request.querystring.page"                    = "method.request.querystring.page",
            "integration.request.querystring.size"                    = "method.request.querystring.size",
            "integration.request.querystring.sort"                    = "method.request.querystring.sort",
            "integration.request.header.Accept-Language"              = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"                = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub_date_ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub_date_end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "payer_company_id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "receipt_number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "legal_ref",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "linked_to_payment_order",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "id_1",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "page",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "sort",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]


      }

      options = local.options
    }

    "/platform/v1/filters/deductions/adjustments-types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/filters/deductions/adjustments-types"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/filters/documents/types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/filters/documents/types"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.status"     = "method.request.querystring.status"
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "array"
              items = {
                type   = "integer"
                format = "int64"
              }
            }
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents/payer/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/payer/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.status"                  = "method.request.querystring.status",
            "integration.request.querystring.due_date_ini"            = "method.request.querystring.due_date_ini",
            "integration.request.querystring.due_date_end"            = "method.request.querystring.due_date_end",
            "integration.request.querystring.pub_date_ini"            = "method.request.querystring.pub_date_ini",
            "integration.request.querystring.pub_date_end"            = "method.request.querystring.pub_date_end",
            "integration.request.querystring.collector_company_id"    = "method.request.querystring.collector_company_id",
            "integration.request.querystring.receipt_number"          = "method.request.querystring.receipt_number",
            "integration.request.querystring.legal_ref"               = "method.request.querystring.legal_ref",
            "integration.request.querystring.linked_to_payment_order" = "method.request.querystring.linked_to_payment_order",
            "integration.request.querystring.id_1"                    = "method.request.querystring.id_1",
            "integration.request.querystring.offline"                 = "method.request.querystring.offline",
            "integration.request.querystring.page"                    = "method.request.querystring.page",
            "integration.request.querystring.size"                    = "method.request.querystring.size",
            "integration.request.querystring.sort"                    = "method.request.querystring.sort",
            "integration.request.header.Accept-Language"              = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"                = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due_date_end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub_date_ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub_date_end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "collector_company_id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "receipt_number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "legal_ref",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "linked_to_payment_order",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "id_1",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "page",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "sort",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/status"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.view"     = "method.request.querystring.view"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses
        parameters = [
          {
            name     = "view",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]
        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents/validate" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/validate"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"   = "method.request.header.Accept-Language"
            "integration.request.querystring.collector-id" = "method.request.querystring.collector-id"
            "integration.request.querystring.sync-debt"    = "method.request.querystring.sync-debt"
            "integration.request.header.Authorization"     = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "collector-id",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "sync-debt",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          { "FirebaseJWTAuthorizer" = [] }
        ]
      }

      options = local.options
    }

    "/platform/v1/documents/pending/{process-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/documents/pending/{process-id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.process-id"        = "method.request.path.process-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "process-id"
            in       = "path"
            required = true
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/schedule" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/schedule"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"      = "method.request.header.Accept-Language"
            "integration.request.querystring.payment-methods" = "method.request.querystring.payment-methods"
            "integration.request.header.Authorization"        = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-methods"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/pending/{process-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/pending/{process-id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.process-id"        = "method.request.path.process-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "process-id"
            in       = "path"
            required = true
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/schedule/{payment_method_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/schedule/{payment_method_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.payment_method_id" = "method.request.path.payment_method_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/schedule/payment-methods/{payment-method-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/schedule/payment-methods/{payment-method-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"

          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.path.payment-method-id" = "method.request.path.payment-method-id"
          }
        }
        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-method-id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/informed/payment-methods" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/informed/payment-methods"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/informed/entities" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/informed/entities"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/informed/payment-order/{id}" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/informed/payment-order/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept"          = "'*/*'",
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type",
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  payment_voucher = {
                    type   = "string",
                    format = "binary"
                  },
                  payment_request = {
                    type = "string"
                  }
                }
              }
            }
          }
        }
      }
      options = local.options
    }

    "platform/v1/payments/collector-payment-order/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/collector-payment-order/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"              = "method.request.header.Accept-Language"
            "integration.request.header.version"                      = "method.request.header.version"
            "integration.request.querystring.payer-company-id"        = "method.request.querystring.payer-company-id"
            "integration.request.querystring.payment-to-debt-allowed" = "method.request.querystring.payment-to-debt-allowed"
            "integration.request.path.id"                             = "method.request.path.id"
            "integration.request.header.Authorization"                = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "version",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payer-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-to-debt-allowed"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/collector/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/collector/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"   = "method.request.header.Accept-Language"
            "integration.request.path.id"                  = "method.request.path.id"
            "integration.request.querystring.payment-type" = "method.request.querystring.payment-type"
            "integration.request.querystring.mode"         = "method.request.querystring.mode"
            "integration.request.header.Authorization"     = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id"
            in       = "path"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name         = "mode"
            in           = "query"
            required     = false
            defaultValue = "inside"
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "platform/v1/payments/collector-payment-order" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/collector-payment-order"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"       = "method.request.header.Accept-Language"
            "integration.request.header.version"               = "method.request.header.version"
            "integration.request.querystring.date-range"       = "method.request.querystring.date-range"
            "integration.request.querystring.date-from"        = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"          = "method.request.querystring.date-to"
            "integration.request.querystring.status"           = "method.request.querystring.status"
            "integration.request.querystring.payment-order-id" = "method.request.querystring.payment-order-id"
            "integration.request.querystring.payer-company-id" = "method.request.querystring.payer-company-id"
            "integration.request.querystring.size"             = "method.request.querystring.size"
            "integration.request.querystring.page"             = "method.request.querystring.page"
            "integration.request.querystring.sort"             = "method.request.querystring.sort"
            "integration.request.header.Authorization"         = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "version",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "date-range",
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-order-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-company-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "platform/v1/payments/collector" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/collector"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"          = "method.request.header.Accept-Language"
            "integration.request.querystring.date-from"           = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"             = "method.request.querystring.date-to"
            "integration.request.querystring.status"              = "method.request.querystring.status"
            "integration.request.querystring.payment-id"          = "method.request.querystring.payment-id"
            "integration.request.querystring.payment-type"        = "method.request.querystring.payment-type"
            "integration.request.querystring.payment-type"        = "method.request.querystring.payment-type"
            "integration.request.querystring.payment-method-id"   = "method.request.querystring.payment-method-id"
            "integration.request.querystring.network-number"      = "method.request.querystring.network-number"
            "integration.request.querystring.bank-network-number" = "method.request.querystring.bank-network-number"
            "integration.request.querystring.applied"             = "method.request.querystring.applied"
            "integration.request.querystring.payer-company-id"    = "method.request.querystring.payer-company-id"
            "integration.request.querystring.size"                = "method.request.querystring.size"
            "integration.request.querystring.page"                = "method.request.querystring.page"
            "integration.request.querystring.sort"                = "method.request.querystring.sort"
            "integration.request.querystring.date-range"          = "method.request.querystring.date-range"
            "integration.request.querystring.entities"            = "method.request.querystring.entities"
            "integration.request.header.Authorization"            = "context.authorizer.token"
          }
          requestTemplates = {
            "application/json" = <<EOF
            #set($allParams = $input.params())
            {
              "params": {
                #foreach($type in $allParams.keySet())
                #set($params = $allParams.get($type))
                "$type": {
                  #foreach($paramName in $params.keySet())
                  #if($paramName == "transaction-number" || $paramName == "check-number" || $paramName == "operation-number" || $paramName == "echeq-number" || $paramName == "transfer-number")
                    #if($util.escapeJavaScript($params.get($paramName)) != "")
                      #set($context.requestOverride.querystring.transaction-number = $util.escapeJavaScript($params.get($paramName)))
                      #break
                    #end
                  #end
                  "$paramName": "$util.escapeJavaScript($params.get($paramName))"#if($foreach.hasNext),#end
                  #end
                }#if($foreach.hasNext),#end
                #end
              }
            }
            EOF
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-method-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "network-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-company-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "bank-network-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "applied"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "transaction-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "check-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "operation-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "echeq-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "transfer-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-range"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "entities"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "platform/v1/payments/collector/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/collector/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"         = "method.request.header.Accept-Language"
            "integration.request.querystring.status"             = "method.request.querystring.status"
            "integration.request.querystring.date-from"          = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"            = "method.request.querystring.date-to"
            "integration.request.querystring.transaction-number" = "method.request.querystring.transaction-number"
            "integration.request.querystring.payment-id"         = "method.request.querystring.payment-id"
            "integration.request.querystring.payer-company-id"   = "method.request.querystring.payer-company-id"
            "integration.request.querystring.payment-type"       = "method.request.querystring.payment-type"
            "integration.request.querystring.lang"               = "method.request.querystring.lang"
            "integration.request.querystring.offline"            = "method.request.querystring.offline"
            "integration.request.querystring.entities"           = "method.request.querystring.entities"
            "integration.request.header.Authorization"           = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "transaction-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payment-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payer-company-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "lang"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "entities"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }
    "/platform/v1/payments/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/{id}/resume" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/{id}/resume"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.querystring.out-url"    = "method.request.querystring.out-url"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "out-url"
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/payments/monitor" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/monitor"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/monitor/{id}" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/monitor/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/previous/echeqs/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/previous/echeqs/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.id"                    = "method.request.path.id"
            "integration.request.querystring.linked_payment" = "method.request.querystring.linked_payment"
            "integration.request.header.Authorization"       = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "id",
            in       = "path",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "linked_payment",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/filter/entities" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/filter/entities"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.entities" = "method.request.querystring.entities"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "entities"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/filter/payment-methods" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/filter/payment-methods"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-methods/echeqs/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-methods/echeqs/status"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.collector-id"       = "method.request.querystring.collector-id"
            "integration.request.querystring.from-payment-order" = "method.request.querystring.from-payment-order"
            "integration.request.header.Authorization"           = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "collector-id"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "from-payment-order",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/agreements" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/agreements"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.collector-id" = "method.request.querystring.collector-id"
            "integration.request.querystring.view"         = "method.request.querystring.view"
            "integration.request.header.Authorization"     = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "collector-id"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "view"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/payment-order/{payment_order_id}/coupons" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/payment-order/{payment_order_id}/coupons"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.payment_order_id" = "method.request.path.payment_order_id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payment_order_id"
            in       = "path"
            required = true
            type     = "number"
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payments/coupons/{id}/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payments/coupons/{id}/download"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "id"
            in       = "path"
            required = true
            type     = "integer"
            format   = "int64"
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payment-request" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-request"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.company_id"           = "method.request.querystring.company_id"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.due_date_ini"         = "method.request.querystring.due_date_ini"
            "integration.request.querystring.due_date_end"         = "method.request.querystring.due_date_end"
            "integration.request.querystring.collector_company_id" = "method.request.querystring.collector_company_id"
            "integration.request.querystring.receipt_number"       = "method.request.querystring.receipt_number"
            "integration.request.querystring.page"                 = "method.request.querystring.page"
            "integration.request.querystring.size"                 = "method.request.querystring.size"
            "integration.request.querystring.sort"                 = "method.request.querystring.sort"
            "integration.request.querystring.table_from"           = "method.request.querystring.table_from"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "company_id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "due_date_ini"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "due_date_end"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "collector_company_id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "receipt_number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "table_from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/claro/payments/new-request" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/claro/payments/new-request"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/payment-request/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-request/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.company_id"           = "method.request.querystring.company_id"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.due_date_ini"         = "method.request.querystring.due_date_ini"
            "integration.request.querystring.due_date_end"         = "method.request.querystring.due_date_end"
            "integration.request.querystring.collector_company_id" = "method.request.querystring.collector_company_id"
            "integration.request.querystring.receipt_number"       = "method.request.querystring.receipt_number"
            "integration.request.querystring.lang"                 = "method.request.querystring.lang"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "company_id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "due_date_ini"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "due_date_end"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "collector_company_id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "receipt_number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "lang"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payment-request/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-request/status"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payment-order/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-order/status"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.accept-language" = "method.request.header.accept-language"
            "integration.request.header.version"         = "method.request.header.version"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "accept-language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "version",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payment-order/{payment_order_id}/documents/advance" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-order/{payment_order_id}/documents/advance"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.accept-language" = "method.request.header.accept-language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.path.payment_order_id"  = "method.request.path.payment_order_id"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "accept-language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment_order_id",
            in       = "path",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payment-request/detail/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-request/detail/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/payment-request/filter/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-request/filter/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/payment-request/filter/companies"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/file-manager/files/attachments/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/file-manager/files/attachments/download"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.file-type" = "method.request.querystring.file-type"
            "integration.request.querystring.file-name" = "method.request.querystring.file-name"
            "integration.request.header.Authorization"  = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "file-type",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "file-name"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/file-manager/files/generate-upload-url" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/file-manager/files/generate-upload-url"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.request-id" = "method.request.querystring.request-id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "request-id"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/file-manager/files/send-email" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/file-manager/files/send-email"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.email"    = "method.request.querystring.email"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "email"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/file-manager/files/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/file-manager/files/download"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
            "integration.request.querystring.id"       = "method.request.querystring.id"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/filter/my-client/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/filter/my-client/status"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/filter/payment-types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/filter/payment-types"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/filter/documents/identification" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/filter/documents/identification"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]


        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/companies/add-image" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/add-image"
          responses = {
            "200" : {
              "statusCode" : "200",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'PUT'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "400" : {
              "statusCode" : "400",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'PUT'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "404" : {
              "statusCode" : "404",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'PUT'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "500" : {
              "statusCode" : "500",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'PUT'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            }
          }

          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.image-type"      = "method.request.header.image-type"
            "integration.request.header.Accept"          = "'*/*'",
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type",
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "image-type",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  image = {
                    type   = "string",
                    format = "binary"
                  }
                }
              }
            }
          }
        }
      }
      options = local.options
    }

    "/platform/v1/companies/{id}/configuration" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/{id}/configuration"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id",
            in       = "path",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/companies/my-company/tax-profile" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company/tax-profile"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.querystring.sort"       = "method.request.querystring.sort"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "page"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company/tax-profile"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/companies/my-company/tax-profile/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company/tax-profile/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id",
            in       = "path",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company/tax-profile/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id",
            in       = "path",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company/tax-profile/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "id",
            in       = "path",
            required = true,
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/companies/my-company/retentions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/companies/my-company/retentions"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/register/document-types/{country_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/document-types/{country_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.country_id"        = "method.request.path.country_id"
            "integration.request.querystring.type"       = "method.request.querystring.type"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "country_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/register/countries" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/countries"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/register/phone-number/verify/{phoneNumber}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/phone-number/verify/{phoneNumber}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.phoneNumber"       = "method.request.path.phoneNumber"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "phoneNumber",
            in       = "path",
            required = false,
            type     = "string"
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/collect-request" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collect-request"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"       = "method.request.header.Accept-Language"
            "integration.request.querystring.company_id"       = "method.request.querystring.company_id"
            "integration.request.querystring.status"           = "method.request.querystring.status"
            "integration.request.querystring.pub_date_ini"     = "method.request.querystring.pub_date_ini"
            "integration.request.querystring.pub_date_end"     = "method.request.querystring.pub_date_end"
            "integration.request.querystring.payer_company_id" = "method.request.querystring.payer_company_id"
            "integration.request.querystring.due_date_ini"     = "method.request.querystring.due_date_ini"
            "integration.request.querystring.due_date_end"     = "method.request.querystring.due_date_end"
            "integration.request.querystring.id1"              = "method.request.querystring.id1"
            "integration.request.querystring.days"             = "method.request.querystring.days"
            "integration.request.querystring.lot_id"           = "method.request.querystring.lot_id"
            "integration.request.querystring.page"             = "method.request.querystring.page"
            "integration.request.querystring.size"             = "method.request.querystring.size"
            "integration.request.querystring.sort"             = "method.request.querystring.sort"
            "integration.request.querystring.receipt_type"     = "method.request.querystring.receipt_type"
            "integration.request.querystring.receipt_number"   = "method.request.querystring.receipt_number"
            "integration.request.header.Authorization"         = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "company_id"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "pub_date_ini"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "pub_date_end"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer_company_id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "due_date_ini"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "due_date_end"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id1"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lot_id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "receipt_type"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "receipt_number"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
            }, {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
        }]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/collect-request/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collect-request/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"       = "method.request.header.Accept-Language"
            "integration.request.querystring.company_id"       = "method.request.querystring.company_id"
            "integration.request.querystring.status"           = "method.request.querystring.status"
            "integration.request.querystring.pub_date_ini"     = "method.request.querystring.pub_date_ini"
            "integration.request.querystring.pub_date_end"     = "method.request.querystring.pub_date_end"
            "integration.request.querystring.payer_company_id" = "method.request.querystring.payer_company_id"
            "integration.request.querystring.due_date_ini"     = "method.request.querystring.due_date_ini"
            "integration.request.querystring.due_date_end"     = "method.request.querystring.due_date_end"
            "integration.request.querystring.id1"              = "method.request.querystring.id1"
            "integration.request.querystring.days"             = "method.request.querystring.days"
            "integration.request.querystring.lot_id"           = "method.request.querystring.lot_id"
            "integration.request.querystring.receipt_type"     = "method.request.querystring.receipt_type"
            "integration.request.querystring.receipt_number"   = "method.request.querystring.receipt_number"
            "integration.request.querystring.lang"             = "method.request.querystring.lang"
            "integration.request.header.Authorization"         = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }


        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "company_id"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "pub_date_ini"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "pub_date_end"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer_company_id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "due_date_ini"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "due_date_end"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "id1"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lot_id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "receipt_type"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "receipt_number"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "lang"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/collect-request/detail/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collect-request/detail/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.id"                = "method.request.path.id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/collect-request/filter/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          contentHandling      = "CONVERT_TO_TEXT"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collect-request/filter/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/file-manager/v1/payment-files" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/file-manager/v1/payment-files"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }

      options = local.options

    }

    "/platform/v1/persons/set-company" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/set-company"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/persons/profile/my-companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/persons/profile/my-companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        responses = local.responses
      }
      options = local.options
    }

    "/platform/v1/account/email-verify" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/email-verify"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.key"        = "method.request.querystring.key",
            "integration.request.querystring.oobCode"    = "method.request.querystring.oobCode"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "key"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "oobCode"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          }
        ]

        responses = local.responses
      }
      options = local.options
    }

    "/platform/v1/register/exists" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/exists"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"        = "method.request.header.Accept-Language"
            "integration.request.querystring.mail"              = "method.request.querystring.mail"
            "integration.request.querystring.documentCountryId" = "method.request.querystring.documentCountryId"
            "integration.request.querystring.documentNumber"    = "method.request.querystring.documentNumber"
            "integration.request.querystring.documentTypeId"    = "method.request.querystring.documentTypeId"
            "integration.request.querystring.code"              = "method.request.querystring.code"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "mail"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "documentCountryId"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "documentNumber"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "documentTypeId"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "code"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          }
        ]

        responses = local.responses
      }
      options = local.options
    }

    "/platform/v1/register/preregister" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/register/preregister"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.lang"            = "method.request.header.lang"
            "integration.request.header.mac-address"     = "method.request.header.mac-address"
            "integration.request.header.ip-address"      = "method.request.header.ip-address"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "lang",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "mac-address",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "ip-address",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/restore-password" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/restore-password"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
          }
        }
        responses = local.responses
        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/account/update-password" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/update-password"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.apiKey"     = "method.request.querystring.apiKey"
            "integration.request.querystring.oobCode"    = "method.request.querystring.oobCode"
            "integration.request.querystring.mail"       = "method.request.querystring.mail"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "apiKey"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "oobCode"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "mail"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          }
        ]

        responses = local.responses

      }
      options = local.options
    }

    "/platform/v1/account/change-password" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/account/change-password"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/business-data-overview/v1/payments/summary-by-payment-method" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/business-data-overview/v1/payments/summary-by-payment-method"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/business-logic/v1/documents/types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/business-logic/v1/documents/types"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.status"             = "method.request.querystring.status"
            "integration.request.querystring.collectorCompanyId" = "method.request.querystring.collectorCompanyId"
            "integration.request.querystring.payerCompanyId"     = "method.request.querystring.payerCompanyId"
            "integration.request.header.Authorization"           = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "array"
              items = {
                type   = "integer"
                format = "int64"
              }
            }
          },
          {
            name     = "collectorCompanyId"
            in       = "query"
            required = true
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "payerCompanyId"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/business-logic/v1/payment-files" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/business-logic/v1/payment-files"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.page"     = "method.request.querystring.page"
            "integration.request.querystring.size"     = "method.request.querystring.size"
            "integration.request.querystring.sort"     = "method.request.querystring.sort"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "page"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
            }, {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/collaborators/register" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/register"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/collaborators/invite" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/invite"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/collaborators" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.companyId"  = "method.request.querystring.companyId"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.querystring.sort"       = "method.request.querystring.sort"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "companyId"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/collaborators/exists" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/exists"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.querystring.mail"       = "method.request.querystring.mail"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "mail"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/collaborators/{collaborator_id}" = {
      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/{collaborator_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.collaborator_id"   = "method.request.path.collaborator_id"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "collaborator_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses
        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/{collaborator_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.collaborator_id" = "method.request.path.collaborator_id"
            "integration.request.header.Authorization" = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        parameters = [
          {
            name     = "collaborator_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          }
          ,
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      delete = {
        x-amazon-apigateway-integration = {
          httpMethod           = "DELETE"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/{collaborator_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.collaborator_id" = "method.request.path.collaborator_id"
            "integration.request.header.Authorization" = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        parameters = [
          {
            name     = "collaborator_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          }
          ,
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/collaborators/{collaborator_id}/history" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/{collaborator_id}/history"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.path.collaborator_id"   = "method.request.path.collaborator_id"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.header.Authorization"   = "context.authorizer.token"

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "collaborator_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/collaborators/search" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/collaborators/search"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Accept-Language"      = "method.request.header.Accept-Language"
            "integration.request.querystring.document_type"   = "method.request.querystring.document_type"
            "integration.request.querystring.document_number" = "method.request.querystring.document_number"
            "integration.request.header.Authorization"        = "context.authorizer.token"
          }
        }

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "document_type"
            in       = "query"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "document_number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        responses = local.responses

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/claro/payments/payers/enabled" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/claro/payments/payers/enabled"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/deductions/retentions/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/retentions/export"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-id"            = "method.request.querystring.payer-id"
            "integration.request.querystring.collector-id"        = "method.request.querystring.collector-id"
            "integration.request.querystring.type"                = "method.request.querystring.type"
            "integration.request.querystring.certificate-number"  = "method.request.querystring.certificate-number"
            "integration.request.querystring.min-retained-amount" = "method.request.querystring.min-retained-amount"
            "integration.request.querystring.max-retained-amount" = "method.request.querystring.max-retained-amount"
            "integration.request.querystring.creation-date-from"  = "method.request.querystring.creation-date-from"
            "integration.request.querystring.creation-date-to"    = "method.request.querystring.creation-date-to"
            "integration.request.querystring.creation-days"       = "method.request.querystring.creation-days"
            "integration.request.querystring.retention-date-from" = "method.request.querystring.retention-date-from"
            "integration.request.querystring.retention-date-to"   = "method.request.querystring.retention-date-to"
            "integration.request.querystring.retention-days"      = "method.request.querystring.retention-days"
            "integration.request.querystring.id"                  = "method.request.querystring.id"
            "integration.request.querystring.view"                = "method.request.querystring.view"
            "integration.request.querystring.offline"             = "method.request.querystring.offline"
            "integration.request.querystring.status"              = "method.request.querystring.status"
            "integration.request.header.Authorization"            = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "collector-id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "certificate-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "min-retained-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "max-retained-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "creation-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "creation-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "creation-days"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "retention-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "retention-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "retention-days"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "view"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/deductions/retentions/types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/retentions/types"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/deductions/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/status"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"

        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/deductions/{payment-order-id}/process" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions/{payment-order-id}/process"
          responses = {
            "200" : {
              "statusCode" : "200",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "400" : {
              "statusCode" : "400",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "422" : {
              "statusCode" : "422",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            },
            "500" : {
              "statusCode" : "500",
              "responseParameters" : {
                "method.response.header.Content-Disposition" : "integration.response.header.Content-Disposition",
                "method.response.header.Access-Control-Allow-Methods" : "'POST'",
                "method.response.header.Content-Type" : "'application/json; charset=UTF-8'",
                "method.response.header.Access-Control-Allow-Headers" : "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type'",
                "method.response.header.Access-Control-Allow-Origin" : "'*'"
              }
            }
          }

          requestParameters = {
            "integration.request.header.Accept-Language" = "method.request.header.Accept-Language"
            "integration.request.header.Authorization"   = "context.authorizer.token"
            "integration.request.header.Accept"          = "'*/*'",
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type",
            "integration.request.path.payment-order-id"  = "method.request.path.payment-order-id",

          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-order-id",
            in       = "path",
            required = true,
            type     = "number"
          },
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

        requestBody = {
          content = {
            "multipart/form-data" = {
              schema = {
                type = "object",
                properties = {
                  retention_file = {
                    type   = "string",
                    format = "binary"
                  }
                }
              }
            }
          }
        }
      }

      options = local.options
    }

    "/platform/v1/deductions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/deductions"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-id"            = "method.request.querystring.payer-id"
            "integration.request.querystring.collector-id"        = "method.request.querystring.collector-id"
            "integration.request.querystring.type"                = "method.request.querystring.type"
            "integration.request.querystring.certificate-number"  = "method.request.querystring.certificate-number"
            "integration.request.querystring.min-retained-amount" = "method.request.querystring.min-retained-amount"
            "integration.request.querystring.max-retained-amount" = "method.request.querystring.max-retained-amount"
            "integration.request.querystring.creation-date-from"  = "method.request.querystring.creation-date-from"
            "integration.request.querystring.creation-date-to"    = "method.request.querystring.creation-date-to"
            "integration.request.querystring.creation-days"       = "method.request.querystring.creation-days"
            "integration.request.querystring.retention-date-from" = "method.request.querystring.retention-date-from"
            "integration.request.querystring.retention-date-to"   = "method.request.querystring.retention-date-to"
            "integration.request.querystring.retention-days"      = "method.request.querystring.retention-days"
            "integration.request.querystring.id"                  = "method.request.querystring.id"
            "integration.request.querystring.view"                = "method.request.querystring.view"
            "integration.request.querystring.size"                = "method.request.querystring.size"
            "integration.request.querystring.page"                = "method.request.querystring.page"
            "integration.request.querystring.sort"                = "method.request.querystring.sort"
            "integration.request.querystring.status"              = "method.request.querystring.status"
            "integration.request.header.Authorization"            = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }
        responses = local.responses
        parameters = [
          {
            name     = "payer-id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "collector-id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "type"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "certificate-number"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "min-retained-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "max-retained-amount"
            in       = "query"
            required = false
            schema = {
              type   = "number"
              format = "double"
            }
          },
          {
            name     = "creation-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "creation-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "creation-days"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "retention-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "retention-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "retention-days"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "id"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "view"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]
        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/platform/v1/notifications" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/notifications"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/notifications/tray" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/notifications/tray"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.unread"   = "method.request.querystring.unread"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "unread",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/notifications/tray"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/notifications/{notification_id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/notifications/{notification_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.notification_id" = "method.request.path.notification_id",
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "notification_id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/notifications/{notification_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.notification_id" = "method.request.path.notification_id",
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "notification_id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/adjustments/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/adjustments/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.view"     = "method.request.querystring.view"
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "view"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]

      }
      options = local.options
    }

    "/platform/v1/rtp/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/rtp/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/rtp/summary/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/rtp/summary/status"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.from-date" = "method.request.querystring.from-date"
            "integration.request.querystring.to-date"   = "method.request.querystring.to-date"
            "integration.request.querystring.days"      = "method.request.querystring.days"
            "integration.request.querystring.lot-id"    = "method.request.querystring.lot-id"
            "integration.request.querystring.status"    = "method.request.querystring.status"
            "integration.request.header.Authorization"  = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "from-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "to-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lot-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/rtp" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/rtp"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.view"                 = "method.request.querystring.view"
            "integration.request.querystring.collector-id"         = "method.request.querystring.collector-id"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.days"                 = "method.request.querystring.days"
            "integration.request.querystring.lot-id"               = "method.request.querystring.lot-id"
            "integration.request.querystring.rtp-id"               = "method.request.querystring.rtp-id"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.expiration-date-from" = "method.request.querystring.expiration-date-from"
            "integration.request.querystring.expiration-date-to"   = "method.request.querystring.expiration-date-to"
            "integration.request.querystring.min-amount"           = "method.request.querystring.min-amount"
            "integration.request.querystring.max-amount"           = "method.request.querystring.max-amount"
            "integration.request.querystring.payer-commercial-id"  = "method.request.querystring.payer-commercial-id"
            "integration.request.querystring.page"                 = "method.request.querystring.page"
            "integration.request.querystring.size"                 = "method.request.querystring.size"
            "integration.request.querystring.sort"                 = "method.request.querystring.sort"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "view"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "collector-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lot-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "rtp-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "expiration-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "expiration-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "min-amount"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "max-amount"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-commercial-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/rtp/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/rtp/export"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Accept-Language"           = "method.request.header.Accept-Language"
            "integration.request.querystring.view"                 = "method.request.querystring.view"
            "integration.request.querystring.collector-id"         = "method.request.querystring.collector-id"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.days"                 = "method.request.querystring.days"
            "integration.request.querystring.lot-id"               = "method.request.querystring.lot-id"
            "integration.request.querystring.rtp-id"               = "method.request.querystring.rtp-id"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.expiration-date-from" = "method.request.querystring.expiration-date-from"
            "integration.request.querystring.expiration-date-to"   = "method.request.querystring.expiration-date-to"
            "integration.request.querystring.min-amount"           = "method.request.querystring.min-amount"
            "integration.request.querystring.max-amount"           = "method.request.querystring.max-amount"
            "integration.request.querystring.payer-commercial-id"  = "method.request.querystring.payer-commercial-id"
            "integration.request.querystring.offline"              = "method.request.querystring.offline"
            "integration.request.querystring.page"                 = "method.request.querystring.page"
            "integration.request.querystring.size"                 = "method.request.querystring.size"
            "integration.request.querystring.sort"                 = "method.request.querystring.sort"
            "integration.request.header.Authorization"             = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Accept-Language",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "view"
            in       = "query"
            required = true
            schema = {
              type = "string"
            }
          },
          {
            name     = "collector-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "lot-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "rtp-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "expiration-date-from"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "expiration-date-to"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "min-amount"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "max-amount"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "payer-commercial-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "offline"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "page"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "size"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/platform/v1/filter/rtp/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/platform/v1/filter/rtp/status"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/notification/v1/message" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/notification/v1/message"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.user-id"  = "method.request.querystring.user-id",
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "user-id",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/notification/v1/message/{notification_id}" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/notification/v1/message/{notification_id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.notification_id" = "method.request.path.notification_id",
            "integration.request.querystring.user-id"  = "method.request.querystring.user-id",
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "notification_id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "user-id",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/document-entry-manager/v1/companies/{company-id}/document-types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/document-entry-manager/v1/companies/{company-id}/document-types"
          contentHandling      = "CONVERT_TO_TEXT"
          passthroughBehavior  = "WHEN_NO_MATCH"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.company-id"      = "method.request.path.company-id"
            "integration.request.header.Authorization" = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "company-id"
            in       = "path"
            required = true
            type     = "number"
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/rtp" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP_PROXY"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.company-commercial-id" = "method.request.querystring.company-commercial-id"
            "integration.request.querystring.status"                = "method.request.querystring.status"
            "integration.request.querystring.from-date"             = "method.request.querystring.from-date"
            "integration.request.querystring.to-date"               = "method.request.querystring.to-date"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.lotId"                 = "method.request.querystring.lotId"
            "integration.request.querystring.rtp-id"                = "method.request.querystring.rtp-id"
            "integration.request.querystring.expiration-date"       = "method.request.querystring.expiration-date"
            "integration.request.header.Authorization"              = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "company-commercial-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "from-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "to-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lotId"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "rtp-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "expiration-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/rtp/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP_PROXY"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.company-commercial-id" = "method.request.querystring.company-commercial-id"
            "integration.request.querystring.status"                = "method.request.querystring.status"
            "integration.request.querystring.from-date"             = "method.request.querystring.from-date"
            "integration.request.querystring.to-date"               = "method.request.querystring.to-date"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.lotId"                 = "method.request.querystring.lotId"
            "integration.request.querystring.rtp-id"                = "method.request.querystring.rtp-id"
            "integration.request.querystring.expiration-date"       = "method.request.querystring.expiration-date"
            "integration.request.header.Authorization"              = "context.authorizer.token"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "company-commercial-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "status"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "from-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "to-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "days"
            in       = "query"
            required = false
            schema = {
              type = "number"
            }
          },
          {
            name     = "lotId"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "rtp-id"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "expiration-date"
            in       = "query"
            required = false
            schema = {
              type = "string"
            }
          },
          {
            name     = "Authorization"
            in       = "header"
            required = false
            type     = "string"
          }
        ]

        security = [
          {
            "FirebaseJWTAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

  }

  x-amazon-apigateway-gateway-responses = {
    "DEFAULT_4XX" : {
      "statusCode" : 401,
      "responseParameters" : {
        "gatewayresponse.header.Access-Control-Allow-Origin" : "'*'"
      },
      "responseTemplates" : {
        "application/json" : "{\"message\":$context.error.messageString}"
      }
    }
  }

  x-amazon-apigateway-binary-media-types = [
    "application/octet-stream",
    "image/png",
    "multipart/form-data",
    "application/pdf"
  ]

})}
  EOT
}
# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {

  openapi_config = {}

  stage_name = local.vars.ENV

  endpoint_type = "EDGE"

  logging_level = "OFF"

  private_link_target_arns = local.vars.AGW_PRIVATE_LINK_TARGETS

  tags = local.tags
}