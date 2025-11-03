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
    "method.response.header.Access-Control-Allow-Credentials" = "'false'"
  }

  headers = {
    "Content-Type" = { type = "string" }
    "Access-Control-Allow-Headers" = { type = "string" }
    "Access-Control-Allow-Methods" = { type = "string" }
    "Access-Control-Allow-Origin" = { type = "string" }
    "Access-Control-Allow-Credentials" = { type = "string" }
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
      httpMethod = "OPTIONS"
      requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
      responses = {
        200 = { 
          statusCode = 200
          responseParameters = local.responseParameters
        }
      }
      passthroughBehavior = "WHEN_NO_MATCH"
    }
    responses = local.responses
  }
}

dependencies {
  paths = [
    "../../cognito/gildarck-user-pool"
  ]
}

dependency "cognito" {
  config_path = "../../cognito/gildarck-user-pool"
}

# dependency "user_crud" {
#   config_path = "../../lambda/user-crud"
# }

# dependency "upload_handler" {
#   config_path = "../../lambda/upload-handler-v2"
# }

# dependency "media_retrieval" {
#   config_path = "../../lambda/media-retrieval"
# }

# dependency "media_delete" {
#   config_path = "../../lambda/media-delete"
# }

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
        CognitoAuthorizer = {
          type = "apiKey"
          name = "Authorization"
          in = "header"
          x-amazon-apigateway-authtype = "cognito_user_pools"
          x-amazon-apigateway-authorizer = {
            type = "cognito_user_pools"
            providerARNs = [dependency.cognito.outputs.user_pool.arn]
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            }
          ]
        }
        options = local.options
      }

      "/auth/logout" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            }
          ]
        }
        options = local.options
      }

      "/auth/refresh" = {
        post = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            },
            {
              name     = "Authorization"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            },
            {
              name     = "Authorization"
              in       = "header"
              required = false
              schema = { type = "string" }
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

      "/platform/v1/users/{id}" = {
        get = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              schema = { type = "string" }
            },
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            },
            {
              name     = "Authorization"
              in       = "header"
              required = false
              schema = { type = "string" }
            }
          ]
          security = [
            {
              "CognitoAuthorizer" = []
            }
          ]
        }

        put = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              schema = { type = "string" }
            },
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            },
            {
              name     = "Authorization"
              in       = "header"
              required = false
              schema = { type = "string" }
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
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-user-crud/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              schema = { type = "string" }
            },
            {
              name     = "Accept-Language"
              in       = "header"
              required = false
              schema = { type = "string" }
            },
            {
              name     = "Authorization"
              in       = "header"
              required = false
              schema = { type = "string" }
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

      # Upload endpoints - Authenticated
      "/upload/initiate" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/complete" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/batch-chunk-urls" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/presigned" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/batch-initiate" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/batch-status" = {
        get = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/health" = {
        get = {
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/analyze" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/upload/check-duplicate" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-upload-handler-v2-dev/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/media/list" = {
        get = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-media-retrieval/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }
      
      "/media/thumbnail/{file_id}" = {
        get = {
          security = [{ CognitoAuthorizer = [] }]
          parameters = [{ name = "file_id", in = "path", required = true, schema = { type = "string" } }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-media-retrieval/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/media/file/{file_id}" = {
        get = {
          security = [{ CognitoAuthorizer = [] }]
          parameters = [{ name = "file_id", in = "path", required = true, schema = { type = "string" } }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-media-retrieval/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        
        options = local.options
      }

      # Google Photos-style delete endpoints
      "/media/delete" = {
        post = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-media-delete/invocations"
            passthroughBehavior = "WHEN_NO_MATCH"
          }
          responses = local.responses
        }
        options = local.options
      }

      "/media/trash" = {
        get = {
          security = [{ CognitoAuthorizer = [] }]
          x-amazon-apigateway-integration = {
            type = "AWS_PROXY"
            httpMethod = "POST"
            uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:496860676881:function:gildarck-media-retrieval/invocations"
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
      function_name = "gildarck-user-crud"
      principal     = "apigateway.amazonaws.com"
      source_arn    = "arn:aws:execute-api:us-east-1:*:*/*/*"
    }
    upload_handler = {
      statement_id  = "AllowExecutionFromAPIGateway"
      action        = "lambda:InvokeFunction"
      function_name = "gildarck-upload-handler-v2-dev"
      principal     = "apigateway.amazonaws.com"
      source_arn    = "arn:aws:execute-api:us-east-1:*:*/*/*"
    }
    media_retrieval = {
      statement_id  = "AllowExecutionFromAPIGateway"
      action        = "lambda:InvokeFunction"
      function_name = "gildarck-media-retrieval"
      principal     = "apigateway.amazonaws.com"
      source_arn    = "arn:aws:execute-api:us-east-1:*:*/*/*"
    }
    media_delete = {
      statement_id  = "AllowExecutionFromAPIGateway"
      action        = "lambda:InvokeFunction"
      function_name = "gildarck-media-delete"
      principal     = "apigateway.amazonaws.com"
      source_arn    = "arn:aws:execute-api:us-east-1:*:*/*/*"
    }
  }
  
  tags = local.tags
}
