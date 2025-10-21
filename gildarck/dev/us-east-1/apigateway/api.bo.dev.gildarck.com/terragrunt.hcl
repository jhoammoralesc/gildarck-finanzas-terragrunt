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
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Content-Disposition,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,path,image-type,lang,mac-address,ip-address'"
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
    "../../cognito/backoffice-user-pool"
  ]
}

dependency "cognito" {
  config_path = "../../cognito/backoffice-user-pool"
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
    description = "API (Backoffice) que expone todos los endpoints para que el backoffice front pueda consumirlos."
  }

  components = {
    securitySchemes = {
      CognitoAuthorizer = {
        type                         = "apiKey"
        name                         = "Authorization"
        in                           = "header"
        x-amazon-apigateway-authtype = "cognito_user_pools"
        x-amazon-apigateway-authorizer = {
          type = "cognito_user_pools"
          providerARNs = [
            dependency.cognito.outputs.user_pool.arn
          ]
        }
      }
    }
  }

  paths = {
    "/backoffice/v1/actuator/health" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/actuator/health"
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

    "/backoffice/v1/log" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/log"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/configurations" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/configurations"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.header.Authorization"   = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            "name"     = "company-id",
            "in"       = "query",
            "required" = true,
            "type"     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/configurations"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/configurations/{id}" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/configurations/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            "name"     = "id",
            "in"       = "path",
            "required" = true,
            "type"     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options

    }

    "/backoffice/v1/configurations/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/configurations/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"   = "method.request.header.Authorization"
            "integration.request.header.filename"        = "method.request.header.filename"
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
          }
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
            name     = "filename",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            name     = "company-id",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]
        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/configurations/import" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/configurations/import"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"   = "method.request.header.Authorization"
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.header.Accept"          = "'*/*'"
            "integration.request.header.Content-Type"    = "method.request.header.Content-Type"
          }
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
            name     = "company-id",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
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
        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/configurations/validate" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/configurations/validate"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.header.Accept"        = "'*/*'"
            "integration.request.header.Content-Type"  = "method.request.header.Content-Type"
          }
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
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
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
        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"        = "method.request.header.Authorization"
            "integration.request.querystring.id"              = "method.request.querystring.id"
            "integration.request.querystring.business-name"   = "method.request.querystring.business-name"
            "integration.request.querystring.document-type"   = "method.request.querystring.document-type"
            "integration.request.querystring.document-number" = "method.request.querystring.document-number"
            "integration.request.querystring.company-type"    = "method.request.querystring.company-type"
            "integration.request.querystring.status"          = "method.request.querystring.status"
            "integration.request.querystring.sort"            = "method.request.querystring.sort"
            "integration.request.querystring.page"            = "method.request.querystring.page"
            "integration.request.querystring.size"            = "method.request.querystring.size"

          }
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
            name     = "id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "business-name",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "document-type",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "document-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "company-type",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "status",
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
            type     = "number"
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/companies"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/companies/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/companies/exist" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/exist"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.document-type"   = "method.request.querystring.document-type"
            "integration.request.querystring.document-number" = "method.request.querystring.document-number"
            "integration.request.header.Authorization"        = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "document-type",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "document-number",
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
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/companies/{id}/collaborators" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/{id}/collaborators"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.querystring.sort"     = "method.request.querystring.sort"
            "integration.request.querystring.page"     = "method.request.querystring.page"
            "integration.request.querystring.size"     = "method.request.querystring.size"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
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
            type     = "number"
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/companies/{id}/relations" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/{id}/relations"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"        = "method.request.header.Authorization"
            "integration.request.path.id"                     = "method.request.path.id"
            "integration.request.querystring.relation-type"   = "method.request.querystring.relation-type"
            "integration.request.querystring.page"            = "method.request.querystring.page"
            "integration.request.querystring.size"            = "method.request.querystring.size"
            "integration.request.querystring.sort"            = "method.request.querystring.sort"
            "integration.request.querystring.business-name"   = "method.request.querystring.business-name"
            "integration.request.querystring.document-number" = "method.request.querystring.document-number"
            "integration.request.querystring.status"          = "method.request.querystring.status"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "relation-type",
            in       = "query",
            required = true,
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
            type     = "number"
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "business-name",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "document-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/companies/{id}/managers" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/{id}/managers"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.querystring.sort"     = "method.request.querystring.sort"
            "integration.request.querystring.page"     = "method.request.querystring.page"
            "integration.request.querystring.size"     = "method.request.querystring.size"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
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
            type     = "number"
          },
          {
            name     = "size",
            in       = "query",
            required = false,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/companies/summary/payment-requests" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/summary/payment-requests"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.pub-date-ini"         = "method.request.querystring.pub-date-ini"
            "integration.request.querystring.pub-date-end"         = "method.request.querystring.pub-date-end"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-company-id",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "pub-date-ini",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "pub-date-end",
            in       = "query",
            required = false,
            schema = {
              type = "string"
            }
          },
          {
            name     = "status",
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
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/companies/summary/payments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/summary/payments"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-company-id",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = false,
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/companies/summary/payment-orders" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/companies/summary/payment-orders"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "payer-company-id",
            in       = "query",
            required = false,
            schema = {
              type = "number"
            }
          },
          {
            name     = "collector-company-id",
            in       = "query",
            required = false,
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/payment-orders/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payment-orders/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.payment-order-id"     = "method.request.querystring.payment-order-id"
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
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
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
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
            name     = "collector-company-id",
            in       = "query",
            required = false,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/roles" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/roles"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/roles/{role_id}/permissions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/roles/{role_id}/permissions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.role_id"         = "method.request.path.role_id"
          }
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
            name     = "role_id"
            in       = "path"
            required = true
            schema = {
              type = "number"
            }
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/roles/permissions" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/roles/permissions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payment-orders/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payment-orders/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.path.id"                          = "method.request.path.id"
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            "name"     = "payer-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "collector-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payment-orders/{id}/reject" = {
      put = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PUT"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payment-orders/{id}/reject"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]
        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payment-orders" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payment-orders"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.page"                 = "method.request.querystring.page",
            "integration.request.querystring.size"                 = "method.request.querystring.size",
            "integration.request.querystring.sort"                 = "method.request.querystring.sort",
            "integration.request.querystring.status"               = "method.request.querystring.status",
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from",
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to",
            "integration.request.querystring.payment-order-id"     = "method.request.querystring.payment-order-id",
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id",
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
          }
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
            "name"     = "page",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "size",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "sort",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "status",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-from",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-to",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payment-order-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "payer-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "collector-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payment-orders" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payment-orders"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.page"                 = "method.request.querystring.page",
            "integration.request.querystring.size"                 = "method.request.querystring.size",
            "integration.request.querystring.sort"                 = "method.request.querystring.sort",
            "integration.request.querystring.status"               = "method.request.querystring.status",
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from",
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to",
            "integration.request.querystring.payment-order-id"     = "method.request.querystring.payment-order-id",
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id",
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
          }
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
            "name"     = "page",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "size",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "sort",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "status",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-from",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-to",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payment-order-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "payer-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "collector-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payment-orders/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payment-orders/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payment-orders/{id}/payments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payment-orders/{id}/payments"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payment-orders/{id}/documents" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payment-orders/{id}/documents"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payment-orders/{id}/deductions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payment-orders/{id}/deductions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payments/informed/{informed-payment-id}/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/informed/{informed-payment-id}/download"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.informed-payment-id" = "method.request.path.informed-payment-id",
            "integration.request.header.Authorization"     = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "informed-payment-id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/payments/informed/{informed-payment-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/informed/{informed-payment-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.informed-payment-id"         = "method.request.path.informed-payment-id",
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id",
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "informed-payment-id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "collector-company-id",
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
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.company-id"          = "method.request.querystring.company-id"
            "integration.request.querystring.type"                = "method.request.querystring.type"
            "integration.request.querystring.certificate-number"  = "method.request.querystring.certificate-number"
            "integration.request.querystring.min-retained-amount" = "method.request.querystring.min-retained-amount"
            "integration.request.querystring.max-retained-amount" = "method.request.querystring.max-retained-amount"
            "integration.request.querystring.creation-date-from"  = "method.request.querystring.creation-date-from"
            "integration.request.querystring.creation-date-to"    = "method.request.querystring.creation-date-to"
            "integration.request.querystring.retention-date-from" = "method.request.querystring.retention-date-from"
            "integration.request.querystring.retention-date-to"   = "method.request.querystring.retention-date-to"
            "integration.request.querystring.creation-days"       = "method.request.querystring.creation-days"
            "integration.request.querystring.retention-days"      = "method.request.querystring.retention-days"
            "integration.request.querystring.id"                  = "method.request.querystring.id"
            "integration.request.querystring.status"              = "method.request.querystring.status"
            "integration.request.querystring.view"                = "method.request.querystring.view"
            "integration.request.querystring.page"                = "method.request.querystring.page"
            "integration.request.querystring.size"                = "method.request.querystring.size"
            "integration.request.querystring.sort"                = "method.request.querystring.sort"
            "integration.request.header.Authorization"            = "method.request.header.Authorization"
          }
        }

        parameters = [
          {
            name     = "company-id"
            in       = "query"
            required = false
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
            name     = "creation-days"
            in       = "query"
            required = false
            schema = {
              type   = "integer"
              format = "int64"
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
            name     = "view"
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/payments/b2b/monitor" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/b2b/monitor"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.payment-order-id"   = "method.request.querystring.payment-order-id"
            "integration.request.querystring.id"                 = "method.request.querystring.id"
            "integration.request.querystring.transaction-number" = "method.request.querystring.transaction-number"
            "integration.request.querystring.applied"            = "method.request.querystring.applied"
            "integration.request.querystring.collector-id"       = "method.request.querystring.collector-id"
            "integration.request.querystring.page"               = "method.request.querystring.page"
            "integration.request.querystring.size"               = "method.request.querystring.size"
            "integration.request.querystring.sort"               = "method.request.querystring.sort"
            "integration.request.header.Authorization"           = "method.request.header.Authorization"
          }
        }

        parameters = [
          {
            name     = "payment-order-id"
            in       = "query"
            required = false
            schema = {
              type = "number"
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
            name     = "transaction-number"
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
              type = "boolean"
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
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions/{retention-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions/{retention-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.retention-id"    = "method.request.path.retention-id",
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "retention-id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions/adjustments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions/adjustments"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.company-id"         = "method.request.querystring.company-id"
            "integration.request.querystring.concept"            = "method.request.querystring.concept"
            "integration.request.querystring.status"             = "method.request.querystring.status"
            "integration.request.querystring.min-amount"         = "method.request.querystring.min-amount"
            "integration.request.querystring.max-amount"         = "method.request.querystring.max-amount"
            "integration.request.querystring.creation-date-from" = "method.request.querystring.creation-date-from"
            "integration.request.querystring.creation-date-to"   = "method.request.querystring.creation-date-to"
            "integration.request.querystring.id"                 = "method.request.querystring.id"
            "integration.request.path.payment-order-id"          = "method.request.path.payment-order-id"
            "integration.request.querystring.days"               = "method.request.querystring.days"
            "integration.request.querystring.view"               = "method.request.querystring.view"
            "integration.request.querystring.page"               = "method.request.querystring.page"
            "integration.request.querystring.size"               = "method.request.querystring.size"
            "integration.request.querystring.sort"               = "method.request.querystring.sort"
            "integration.request.header.Authorization"           = "method.request.header.Authorization"
          }
        }

        parameters = [
          {
            name     = "company-id"
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
              type = "string"
            }
          },
          {
            name     = "payment-order-id",
            in       = "path",
            required = true,
            type     = "number"
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
            name     = "view"
            in       = "query"
            required = true
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions/adjustments/types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions/adjustments/types"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions/types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions/types"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
        }

        parameters = [
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
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions/status"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/deductions/{retention-id}/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/deductions/{retention-id}/download"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.retention-id"    = "method.request.path.retention-id"
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        parameters = [
          {
            name     = "retention-id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
        ]

        responses = local.responses

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/documents" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/documents"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id",
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id",
            "integration.request.querystring.status"               = "method.request.querystring.status",
            "integration.request.querystring.due-date-ini"         = "method.request.querystring.due-date-ini",
            "integration.request.querystring.due-date-end"         = "method.request.querystring.due-date-end",
            "integration.request.querystring.pub-date-ini"         = "method.request.querystring.pub-date-ini",
            "integration.request.querystring.pub-date-end"         = "method.request.querystring.pub-date-end",
            "integration.request.querystring.receipt-number"       = "method.request.querystring.receipt-number",
            "integration.request.querystring.legal-ref"            = "method.request.querystring.legal-ref",
            "integration.request.querystring.payer-doc-number"     = "method.request.querystring.payer-doc-number",
            "integration.request.querystring.lot-id"               = "method.request.querystring.lot-id",
            "integration.request.querystring.has-payment-order"    = "method.request.querystring.has-payment-order",
            "integration.request.querystring.page"                 = "method.request.querystring.page",
            "integration.request.querystring.size"                 = "method.request.querystring.size",
            "integration.request.querystring.sort"                 = "method.request.querystring.sort",
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "collector-company-id",
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
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due-date-ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due-date-end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub-date-ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub-date-end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "receipt-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "legal-ref",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "payer-doc-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "lot-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "has-payment-order",
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/documents/export/excel" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/documents/export/excel"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id",
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id",
            "integration.request.querystring.status"               = "method.request.querystring.status",
            "integration.request.querystring.due-date-ini"         = "method.request.querystring.due-date-ini",
            "integration.request.querystring.due-date-end"         = "method.request.querystring.due-date-end",
            "integration.request.querystring.pub-date-ini"         = "method.request.querystring.pub-date-ini",
            "integration.request.querystring.pub-date-end"         = "method.request.querystring.pub-date-end",
            "integration.request.querystring.receipt-number"       = "method.request.querystring.receipt-number",
            "integration.request.querystring.legal-ref"            = "method.request.querystring.legal-ref",
            "integration.request.querystring.payer-doc-number"     = "method.request.querystring.payer-doc-number",
            "integration.request.querystring.lot-id"               = "method.request.querystring.lot-id",
            "integration.request.querystring.has-payment-order"    = "method.request.querystring.has-payment-order",
            "integration.request.querystring.offline"              = "method.request.querystring.offline",
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
        }

        responses = local.responses

        parameters = [
          {
            name     = "collector-company-id",
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
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due-date-ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "due-date-end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub-date-ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub-date-end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "receipt-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "legal-ref",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "payer-doc-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "lot-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "has-payment-order",
            in       = "query",
            required = false,
            type     = "boolean"
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
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v2/documents/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/documents/{id}"
          responses            = local.integration_responses
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id",
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
          passthroughBehavior = "WHEN_NO_MATCH"
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/payments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payments"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.page"                 = "method.request.querystring.page",
            "integration.request.querystring.size"                 = "method.request.querystring.size",
            "integration.request.querystring.sort"                 = "method.request.querystring.sort",
            "integration.request.querystring.status"               = "method.request.querystring.status",
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from",
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to",
            "integration.request.querystring.transaction-number"   = "method.request.querystring.transaction-number",
            "integration.request.querystring.payment-id"           = "method.request.querystring.payment-id",
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id",
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.bank-network-number"  = "method.request.querystring.bank-network-number"
          }
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
            "name"     = "page",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "size",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "sort",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "status",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-from",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-to",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "transaction-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payment-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "payer-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "collector-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "bank-network-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payments/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payments/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.transaction-number"   = "method.request.querystring.transaction-number"
            "integration.request.querystring.payment-id"           = "method.request.querystring.payment-id"
            "integration.request.querystring.bank-network-number"  = "method.request.querystring.bank-network-number"
          }
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
            name     = "payer-company-id",
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
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
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
            name     = "transaction-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "payment-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            "name"     = "bank-network-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payment-requests" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payment-requests"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"              = "method.request.header.Authorization"
            "integration.request.querystring.page"                  = "method.request.querystring.page",
            "integration.request.querystring.size"                  = "method.request.querystring.size",
            "integration.request.querystring.sort"                  = "method.request.querystring.sort",
            "integration.request.querystring.company-id"            = "method.request.querystring.company-id",
            "integration.request.querystring.company-type"          = "method.request.querystring.company-type",
            "integration.request.querystring.status"                = "method.request.querystring.status",
            "integration.request.querystring.pub-date-ini"          = "method.request.querystring.pub-date-ini",
            "integration.request.querystring.pub-date-end"          = "method.request.querystring.pub-date-end",
            "integration.request.querystring.payer-document-number" = "method.request.querystring.payer-document-number",
            "integration.request.querystring.due-date-ini"          = "method.request.querystring.due-date-ini",
            "integration.request.querystring.due-date-end"          = "method.request.querystring.due-date-end",
            "integration.request.querystring.lot-id"                = "method.request.querystring.lot-id",
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.receipt-number"        = "method.request.querystring.receipt-number"

          }
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
            "name"     = "page",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "size",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "sort",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "company-id",
            "in"       = "query",
            "required" = true,
            "type"     = "number"
          },
          {
            "name"     = "company-type",
            "in"       = "query",
            "required" = true,
            "type"     = "number"
          },
          {
            "name"     = "status",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "pub-date-ini",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "pub-date-end",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payer-document-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "due-date-ini",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "due-date-end",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "lot-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "days",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "receipt-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payment-requests/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payment-requests/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"       = "method.request.header.Authorization"
            "integration.request.querystring.company-id"     = "method.request.querystring.company-id"
            "integration.request.querystring.company-type"   = "method.request.querystring.company-type"
            "integration.request.querystring.status"         = "method.request.querystring.status"
            "integration.request.querystring.pub-date-ini"   = "method.request.querystring.pub-date-ini"
            "integration.request.querystring.pub-date-end"   = "method.request.querystring.pub-date-end"
            "integration.request.querystring.lot-id"         = "method.request.querystring.lot-id"
            "integration.request.querystring.receipt-number" = "method.request.querystring.receipt-number"
          }
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
            name     = "company-id",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "company-type",
            in       = "query",
            required = true,
            type     = "number"
          },
          {
            name     = "status",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub-date-ini",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "pub-date-end",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "lot-id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "receipt-number",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/payments/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/payments/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/invitations/upload" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/invitations/upload"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.header.Accept"        = "'*/*'"
            "integration.request.header.Content-Type"  = "method.request.header.Content-Type"
          }
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
            name     = "Content-Type",
            in       = "header",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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

    "/backoffice/v1/users" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"            = "method.request.header.Authorization"
            "integration.request.querystring.id"                  = "method.request.querystring.id"
            "integration.request.querystring.page"                = "method.request.querystring.page"
            "integration.request.querystring.size"                = "method.request.querystring.size"
            "integration.request.querystring.sort"                = "method.request.querystring.sort"
            "integration.request.querystring.name"                = "method.request.querystring.name"
            "integration.request.querystring.document-number"     = "method.request.querystring.document-number"
            "integration.request.querystring.email"               = "method.request.querystring.email"
            "integration.request.querystring.status"              = "method.request.querystring.status"
            "integration.request.querystring.status-registration" = "method.request.querystring.status-registration"
            "integration.request.querystring.has-company"         = "method.request.querystring.has-company"
          }
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
            name     = "id",
            in       = "query",
            required = false,
            type     = "number"
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
            name     = "name",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "document-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "email",
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
            name     = "status-registration",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "has-company",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/user-permissions" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/user-permissions"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/profiles" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/profiles"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/search" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/search"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"        = "method.request.header.Authorization"
            "integration.request.querystring.document-type"   = "method.request.querystring.document-type"
            "integration.request.querystring.document-number" = "method.request.querystring.document-number"
            "integration.request.querystring.company-id"      = "method.request.querystring.company-id"
          }
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
            name     = "document-type",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "document-number",
            in       = "query",
            required = true,
            type     = "string"
          },
          {
            name     = "company-id",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/exists" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/exists"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.querystring.mail"     = "method.request.querystring.mail"
          }
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
            name     = "mail",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/export/xlsx" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/export/xlsx"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"            = "method.request.header.Authorization"
            "integration.request.querystring.id"                  = "method.request.querystring.id"
            "integration.request.querystring.name"                = "method.request.querystring.name"
            "integration.request.querystring.document-number"     = "method.request.querystring.document-number"
            "integration.request.querystring.email"               = "method.request.querystring.email"
            "integration.request.querystring.status"              = "method.request.querystring.status"
            "integration.request.querystring.status-registration" = "method.request.querystring.status-registration"
          }
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
            name     = "id",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "name",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "document-number",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "email",
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
            name     = "status-registration",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/register" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/register"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/invite" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/invite"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"            = "method.request.header.Authorization"
            "integration.request.path.id"                         = "method.request.path.id"
            "integration.request.querystring.status-registration" = "method.request.querystring.status-registration",
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "status-registration",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/users/{id}/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/users/{id}/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"            = "method.request.header.Authorization"
            "integration.request.path.id"                         = "method.request.path.id"
            "integration.request.querystring.status-registration" = "method.request.querystring.status-registration",
          }
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "status-registration",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/address/countries" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/address/countries"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
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
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/address/provinces" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/address/provinces"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"   = "method.request.header.Authorization"
            "integration.request.querystring.country-id" = "method.request.querystring.country-id"
          }
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
            name     = "country-id",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/address/locations" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/address/locations"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"    = "method.request.header.Authorization"
            "integration.request.querystring.province-id" = "method.request.querystring.province-id"
          }
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
            name     = "province-id",
            in       = "query",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payments" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.page"                 = "method.request.querystring.page",
            "integration.request.querystring.size"                 = "method.request.querystring.size",
            "integration.request.querystring.sort"                 = "method.request.querystring.sort",
            "integration.request.querystring.status"               = "method.request.querystring.status",
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from",
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to",
            "integration.request.querystring.transaction-number"   = "method.request.querystring.transaction-number",
            "integration.request.querystring.payment-id"           = "method.request.querystring.payment-id",
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id",
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.payment-type"         = "method.request.querystring.payment-type"
            "integration.request.querystring.payment-method-id"    = "method.request.querystring.payment-method-id"
            "integration.request.querystring.bank-network-number"  = "method.request.querystring.bank-network-number"
            "integration.request.querystring.linked-payment-order" = "method.request.querystring.linked-payment-order"
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
            name     = "Authorization",
            in       = "header",
            required = false,
            type     = "string"
          },
          {
            "name"     = "page",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "size",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "sort",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "status",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-from",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "date-to",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "transaction-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payment-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "payer-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "collector-company-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "bank-network-number",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payment-type",
            "in"       = "query",
            "required" = false,
            "type"     = "string"
          },
          {
            "name"     = "payment-method-id",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          },
          {
            "name"     = "linked-payment-order",
            "in"       = "query",
            "required" = false,
            "type"     = "boolean"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payments/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"     = "method.request.header.Authorization"
            "integration.request.path.id"                  = "method.request.path.id"
            "integration.request.querystring.payment-type" = "method.request.querystring.payment-type"
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          },
          {
            name     = "payment-type",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]
        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payments/export" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"             = "method.request.header.Authorization"
            "integration.request.querystring.status"               = "method.request.querystring.status"
            "integration.request.querystring.date-from"            = "method.request.querystring.date-from"
            "integration.request.querystring.date-to"              = "method.request.querystring.date-to"
            "integration.request.querystring.transaction-number"   = "method.request.querystring.transaction-number"
            "integration.request.querystring.payment-id"           = "method.request.querystring.payment-id"
            "integration.request.querystring.payer-company-id"     = "method.request.querystring.payer-company-id"
            "integration.request.querystring.collector-company-id" = "method.request.querystring.collector-company-id"
            "integration.request.querystring.bank-network-number"  = "method.request.querystring.bank-network-number"
            "integration.request.querystring.payment-type"         = "method.request.querystring.payment-type"
            "integration.request.querystring.payment-method-id"    = "method.request.querystring.payment-method-id"
            "integration.request.querystring.linked-payment-order" = "method.request.querystring.linked-payment-order"
            "integration.request.querystring.offline"              = "method.request.querystring.offline"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization"
            in       = "header"
            required = true
            type     = "string"
          },
          {
            name     = "status"
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
            name     = "transaction-number"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "payment-id"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "payer-company-id"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "collector-company-id"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "bank-network-number"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "payment-type"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "payment-method-id"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "linked-payment-order"
            in       = "query"
            required = false
            type     = "boolean"
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
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }


    "/backoffice/v2/payments/previous/movements/{previous-payment-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/previous/movements/{previous-payment-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"     = "method.request.header.Authorization"
            "integration.request.path.previous-payment-id" = "method.request.path.previous-payment-id"
          }
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
            name     = "previous-payment-id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v2/payments/previous/echeqs/{previous-payment-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v2/payments/previous/echeqs/{previous-payment-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"     = "method.request.header.Authorization"
            "integration.request.path.previous-payment-id" = "method.request.path.previous-payment-id"
          }
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
            name     = "previous-payment-id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }
      options = local.options
    }

    "/backoffice/v1/notifications" = {
      post = {
        x-amazon-apigateway-integration = {
          httpMethod           = "POST"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/notifications"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.querystring.active"   = "method.request.querystring.active"
            "integration.request.querystring.page"     = "method.request.querystring.page"
            "integration.request.querystring.size"     = "method.request.querystring.size"
            "integration.request.querystring.sort"     = "method.request.querystring.sort"
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
            name     = "active",
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
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/profiles" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/profiles"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"      = "method.request.header.Authorization"
            "integration.request.querystring.roles"         = "method.request.querystring.roles"
            "integration.request.querystring.company-types" = "method.request.querystring.company-types"
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
            name     = "roles",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "company-types",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/company-types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/company-types"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"      = "method.request.header.Authorization"
            "integration.request.querystring.roles"         = "method.request.querystring.roles"
            "integration.request.querystring.company-types" = "method.request.querystring.company-types"
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
            name     = "roles",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "company-types",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/audience" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/audience"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"      = "method.request.header.Authorization"
            "integration.request.querystring.roles"         = "method.request.querystring.roles"
            "integration.request.querystring.company-types" = "method.request.querystring.company-types"
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
            name     = "roles",
            in       = "query",
            required = false,
            type     = "string"
          },
          {
            name     = "company-types",
            in       = "query",
            required = false,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/notifications/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/{id}/status" = {
      patch = {
        x-amazon-apigateway-integration = {
          httpMethod           = "PATCH"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/{id}/status"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.id"              = "method.request.path.id"
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
            name     = "id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/priorities" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/priorities"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/channels" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/channels"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/types" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/types"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/notifications/sub-types/{type-id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/notifications/sub-types/{type-id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.path.type-id"         = "method.request.path.type-id"
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
            name     = "type-id",
            in       = "path",
            required = true,
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/platform/maintenance" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/platform/maintenance"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/platform/maintenance"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/platform/maintenance"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/platform/maintenance/users" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/platform/maintenance/users"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/platform/maintenance/users"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          uri                  = "https://${local.name}/backoffice/v1/platform/maintenance/users"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/files/download" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/files/download"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.querystring.id"       = "method.request.querystring.id"
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
            name     = "id",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/files/generate-download-url" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/files/generate-download-url"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
            "integration.request.querystring.id"       = "method.request.querystring.id"
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
            name     = "id",
            in       = "query",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"              = "method.request.header.Authorization"
            "integration.request.querystring.company-commercial-id" = "method.request.querystring.company-commercial-id"
            "integration.request.querystring.status"                = "method.request.querystring.status"
            "integration.request.querystring.from-date"             = "method.request.querystring.from-date"
            "integration.request.querystring.to-date"               = "method.request.querystring.to-date"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.page"                  = "method.request.querystring.page"
            "integration.request.querystring.size"                  = "method.request.querystring.size"
            "integration.request.querystring.sort"                  = "method.request.querystring.sort"
            "integration.request.querystring.lotId"                 = "method.request.querystring.lotId"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization"
            in       = "header"
            required = true
            type     = "string"
          },
          {
            name     = "company-commercial-id"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "status"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "from-date"
            in       = "query"
            required = true
            type     = "string"
          },
          {
            name     = "to-date"
            in       = "query"
            required = true
            type     = "string"
          },
          {
            name     = "days"
            in       = "query"
            required = true
            type     = "number"
          },
          {
            name     = "page"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "size"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "sort"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            "name"     = "lotId",
            "in"       = "query",
            "required" = false,
            "type"     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp/export"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"              = "method.request.header.Authorization"
            "integration.request.querystring.company-commercial-id" = "method.request.querystring.company-commercial-id"
            "integration.request.querystring.status"                = "method.request.querystring.status"
            "integration.request.querystring.from-date"             = "method.request.querystring.from-date"
            "integration.request.querystring.to-date"               = "method.request.querystring.to-date"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.lotId"                 = "method.request.querystring.lotId"
            "integration.request.querystring.offline"               = "method.request.querystring.offline"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization"
            in       = "header"
            required = true
            type     = "string"
          },
          {
            name     = "company-commercial-id"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "status"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "from-date"
            in       = "query"
            required = true
            type     = "string"
          },
          {
            name     = "to-date"
            in       = "query"
            required = true
            type     = "string"
          },
          {
            name     = "days"
            in       = "query"
            required = true
            type     = "number"
          },
          {
            name     = "lotId",
            in       = "query",
            required = false,
            type     = "number"
          },
          {
            name     = "offline",
            in       = "query",
            required = false,
            type     = "boolean"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/tax-profile" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/tax-profile"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"   = "method.request.header.Authorization"
            "integration.request.querystring.company-id" = "method.request.querystring.company-id"
            "integration.request.querystring.active"     = "method.request.querystring.active"
            "integration.request.querystring.page"       = "method.request.querystring.page"
            "integration.request.querystring.size"       = "method.request.querystring.size"
            "integration.request.querystring.sort"       = "method.request.querystring.sort"
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
            "name"     = "company-id",
            "in"       = "query",
            "required" = true,
            "type"     = "number"
          },
          {
            name     = "active",
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
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/rtp/{id}" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp/{id}"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.path.id"              = "method.request.path.id"
            "integration.request.header.Authorization" = "method.request.header.Authorization"

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
            name     = "Authorization",
            in       = "header",
            required = true,
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/rtp/summary/status" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp/summary/status"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization"              = "method.request.header.Authorization"
            "integration.request.querystring.company-commercial-id" = "method.request.querystring.company-commercial-id"
            "integration.request.querystring.status"                = "method.request.querystring.status"
            "integration.request.querystring.from-date"             = "method.request.querystring.from-date"
            "integration.request.querystring.to-date"               = "method.request.querystring.to-date"
            "integration.request.querystring.days"                  = "method.request.querystring.days"
            "integration.request.querystring.lot-id"                = "method.request.querystring.lot-id"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization"
            in       = "header"
            required = true
            type     = "string"
          },
          {
            name     = "company-commercial-id"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "status"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "from-date"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "to-date"
            in       = "query"
            required = false
            type     = "string"
          },
          {
            name     = "days"
            in       = "query"
            required = false
            type     = "number"
          },
          {
            name     = "lot-id"
            in       = "query"
            required = false
            type     = "number"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
          }
        ]
      }

      options = local.options
    }

    "/backoffice/v1/rtp/companies" = {
      get = {
        x-amazon-apigateway-integration = {
          httpMethod           = "GET"
          payloadFormatVersion = "1.0"
          type                 = "HTTP"
          connectionType       = "VPC_LINK"
          connectionId         = local.vpc_link_id
          uri                  = "https://${local.name}/backoffice/v1/rtp/companies"
          responses            = local.integration_responses
          passthroughBehavior  = "WHEN_NO_MATCH"
          requestParameters = {
            "integration.request.header.Authorization" = "method.request.header.Authorization"
          }
        }

        responses = local.responses

        parameters = [
          {
            name     = "Authorization"
            in       = "header"
            required = true
            type     = "string"
          }
        ]

        security = [
          {
            "CognitoAuthorizer" = []
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

  name = "back-office"

  stage_name = local.vars.ENV

  endpoint_type = "EDGE"

  logging_level = "OFF"

  // private_link_target_arns = local.vars.AGW_PRIVATE_LINK_TARGETS

  tags = local.tags
}
