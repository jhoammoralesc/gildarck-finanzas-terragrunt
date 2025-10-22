# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION - GILDARCK PHOTO API
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = include.envcommon.locals.base_source_url
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/apigateway/vpclink-api.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "api.dev.gildarck.com"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
  vpc_link_id  = "y38ap6"
  
  responseParameters = {
    "method.response.header.Content-Type"                 = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  headers = {
    "Content-Type" = { "type" = "string" }
    "Access-Control-Allow-Origin" = { "type" = "string" }
    "Access-Control-Allow-Headers" = { "type" = "string" }
    "Access-Control-Allow-Methods" = { "type" = "string" }
  }

  integrationResponses = {
    200 = { statusCode = 200, responseParameters = local.responseParameters }
    400 = { statusCode = 400, responseParameters = local.responseParameters }
    401 = { statusCode = 401, responseParameters = local.responseParameters }
    404 = { statusCode = 404, responseParameters = local.responseParameters }
    500 = { statusCode = 500, responseParameters = local.responseParameters }
  }

  responses = {
    200 = { description = "200 response", headers = local.headers }
    400 = { description = "400 response", headers = local.headers }
    401 = { description = "401 response", headers = local.headers }
    404 = { description = "404 response", headers = local.headers }
    500 = { description = "500 response", headers = local.headers }
  }
}

inputs = {
  name        = local.name
  description = "Gildarck Photo Management API"
  tags        = local.tags

  # Photo Management Endpoints
  resources = {
    # Photos CRUD
    "/photos" = {
      methods = {
        "GET" = {
          description          = "Get all photos"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "POST" = {
          description          = "Upload new photo"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "OPTIONS" = {
          description          = "CORS preflight"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
      }
    }

    "/photos/{id}" = {
      methods = {
        "GET" = {
          description          = "Get photo by ID"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "PUT" = {
          description          = "Update photo"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "DELETE" = {
          description          = "Delete photo"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "OPTIONS" = {
          description          = "CORS preflight"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
      }
    }

    # Albums CRUD
    "/albums" = {
      methods = {
        "GET" = {
          description          = "Get all albums"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "POST" = {
          description          = "Create new album"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "OPTIONS" = {
          description          = "CORS preflight"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
      }
    }

    "/albums/{id}" = {
      methods = {
        "GET" = {
          description          = "Get album by ID"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "PUT" = {
          description          = "Update album"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "DELETE" = {
          description          = "Delete album"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "OPTIONS" = {
          description          = "CORS preflight"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
      }
    }

    # User management
    "/user/profile" = {
      methods = {
        "GET" = {
          description          = "Get user profile"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "PUT" = {
          description          = "Update user profile"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
        "OPTIONS" = {
          description          = "CORS preflight"
          integrationResponses = local.integrationResponses
          responses            = local.responses
        }
      }
    }
  }

  vpc_link_id = local.vpc_link_id
  domain_name = local.name
}
