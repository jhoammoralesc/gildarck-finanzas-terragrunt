# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "git@github.com:jhoammoralesc/infrastructure-terraform-modules.git//aws-apigateway"
}

include "root" {
  path = find_in_parent_folders()
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "api.dev.gildarck.com"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = { 
    name = local.name
    owner = "gildarck"
    environment = "dev"
    region = "us-east-1"
    service = "apigateway"
  }
  
  responseParameters = {
    "method.response.header.Content-Type"                 = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,DELETE,PATCH,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  headers = {
    "Content-Type" = { "type" = "string" }
    "Access-Control-Allow-Headers" = { "type" = "string" }
    "Access-Control-Allow-Methods" = { "type" = "string" }
    "Access-Control-Allow-Origin" = { "type" = "string" }
  }

  integration_responses = {
    200 = { statusCode = 200, responseParameters = local.responseParameters }
    201 = { statusCode = 201, responseParameters = local.responseParameters }
    400 = { statusCode = 400, responseParameters = local.responseParameters }
    401 = { statusCode = 401, responseParameters = local.responseParameters }
    403 = { statusCode = 403, responseParameters = local.responseParameters }
    404 = { statusCode = 404, responseParameters = local.responseParameters }
    500 = { statusCode = 500, responseParameters = local.responseParameters }
  }

  responses = {
    200 = { description = "200 response", headers = local.headers }
    201 = { description = "201 response", headers = local.headers }
    400 = { description = "400 response", headers = local.headers }
    401 = { description = "401 response", headers = local.headers }
    403 = { description = "403 response", headers = local.headers }
    404 = { description = "404 response", headers = local.headers }
    500 = { description = "500 response", headers = local.headers }
  }

  options = {
    consumes = ["application/json"]
    x-amazon-apigateway-integration = {
      type = "MOCK"
      requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
      responses = local.integration_responses
      passthroughBehavior = "WHEN_NO_MATCH"
    }
    responses = local.responses
  }
}

dependencies {
  paths = [
    "../../lambda/function-authorizer",
    "../../lambda/user-crud"
  ]
}

dependency "authorizer" {
  config_path = "../../lambda/function-authorizer"
}

dependency "user_crud" {
  config_path = "../../lambda/user-crud"
}

inputs = {
  api_name = local.name
  api_description = "GILDARCK Photo Management API - private VPC with MOCK endpoints"
  
  # Stage configuration
  stage_name = "dev"
  
  # Disable logging temporarily to avoid CloudWatch role requirement
  logging_level = "OFF"
  
  # Public API Gateway configuration (EDGE)
  endpoint_type = "EDGE"
  
  openapi_config = {
    openapi = "3.0.1"
    info = {
      title = local.name
      version = "1.0"
      description = "GILDARCK Private API with Firebase JWT authorization - MOCK endpoints for development"
    }
    
    components = {
      securitySchemes = {
        FirebaseJWTAuthorizer = {
          type = "apiKey"
          name = "Authorization"
          in = "header"
          x-amazon-apigateway-authtype = "custom"
          x-amazon-apigateway-authorizer = {
            type = "request"
            authorizerUri = dependency.authorizer.outputs.lambda_function_invoke_arn
            authorizerResultTtlInSeconds = 0
            identitySource = "method.request.header.Authorization"
          }
        }
      }
    }
    
    paths = {
      # Auth endpoints - No authentication required
      "/auth/login" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              type     = "string"
            }
          ]
        }
        options = local.options
      }

      "/auth/register" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              type     = "string"
            }
          ]
        }
        options = local.options
      }

      "/auth/change-password" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              type     = "string"
            }
          ]
        }
        options = local.options
      }

      "/auth/set-new-password" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              type     = "string"
            }
          ]
        }
        options = local.options
      }

      # Legacy endpoints - Keep for backward compatibility but redirect to lambda
      "/platform/v1/account/register" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              type     = "string"
            }
          ]
        }
        options = local.options
      }

      "/platform/v1/account/login" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              type     = "string"
            }
          ]
        }
        options = local.options
      }

      "/platform/v1/users" = {
        get = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
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

        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
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

      "/platform/v1/users/{id}" = {
        get = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "Accept-Language"
              in       = "header"
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

        put = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "Accept-Language"
              in       = "header"
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

        delete = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = dependency.user_crud.outputs.lambda_function_invoke_arn
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "Accept-Language"
              in       = "header"
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

      "/photos" = {
        get = {
          security = [{ FirebaseJWTAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "MOCK"
            requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
            responses = {
              200 = {
                statusCode = 200
                responseTemplates = { "application/json" = "{\"message\": \"List photos - MOCK endpoint\", \"photos\": []}" }
                responseParameters = local.responseParameters
              }
            }
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        
        post = {
          security = [{ FirebaseJWTAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "MOCK"
            requestTemplates = { "application/json" = "{\"statusCode\": 201}" }
            responses = {
              201 = {
                statusCode = 201
                responseTemplates = { "application/json" = "{\"message\": \"Photo uploaded - MOCK endpoint\", \"id\": \"mock-photo-123\"}" }
                responseParameters = local.responseParameters
              }
            }
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        
        options = local.options
      }
      
      "/photos/{id}" = {
        get = {
          security = [{ FirebaseJWTAuthorizer = [] }]
          parameters = [{ name = "id", in = "path", required = true, type = "string" }]
          x-amazon-apigateway-integration = {
            type = "MOCK"
            requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
            responses = {
              200 = {
                statusCode = 200
                responseTemplates = { "application/json" = "{\"message\": \"Get photo by ID - MOCK endpoint\", \"id\": \"$input.params('id')\"}" }
                responseParameters = local.responseParameters
              }
            }
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        
        delete = {
          security = [{ FirebaseJWTAuthorizer = [] }]
          parameters = [{ name = "id", in = "path", required = true, type = "string" }]
          x-amazon-apigateway-integration = {
            type = "MOCK"
            requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
            responses = {
              200 = {
                statusCode = 200
                responseTemplates = { "application/json" = "{\"message\": \"Photo deleted - MOCK endpoint\", \"id\": \"$input.params('id')\"}" }
                responseParameters = local.responseParameters
              }
            }
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        
        options = local.options
      }
    }
  }
  
  # Lambda permissions for API Gateway
  lambda_permissions = {
    user_crud = {
      statement_id  = "AllowExecutionFromAPIGateway"
      action        = "lambda:InvokeFunction"
      function_name = dependency.user_crud.outputs.lambda_function_name
      principal     = "apigateway.amazonaws.com"
      source_arn    = "arn:aws:execute-api:us-east-1:*:*/*/*"
    }
  }
  
  tags = local.tags
}
