# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for route53/domain-registration. The common variables for each environment to
# deploy route53/domain-registration are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If any environment
# needs to deploy a different module version, it should redefine this block with a different ref to override the
# deployed version.
terraform {
  source = "${local.base_source_url}//modules/aws/route53-domain-registration?ref=v0.90.4"
}


# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  env = local.environment_vars.locals.environment

  # Expose the base source URL so different versions of the module can be deployed in different environments. This will
  # be used to construct the terraform block in the child terragrunt configurations.
  base_source_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Domain registration configuration
  domain_name = ""
  
  # Contact information for domain registration (Colombia)
  admin_contact = {
    organization_name = "Gildarck"
    first_name       = "Admin"
    last_name        = "Gildarck"
    email            = "admin@gildarck.com"
    phone_number     = "+573213219424"
    address_line_1   = "Calle 123 #45-67"
    city             = "Medellin"
    state            = "Antioquia"
    zip_code         = "050021"
    country_code     = "CO"
    contact_type     = "COMPANY"
  }
  
  registrant_contact = {
    organization_name = "Gildarck"
    first_name       = "Admin"
    last_name        = "Gildarck"
    email            = "admin@gildarck.com"
    phone_number     = "+573213219424"
    address_line_1   = "Calle 123 #45-67"
    city             = "Medellin"
    state            = "Antioquia"
    zip_code         = "050021"
    country_code     = "CO"
    contact_type     = "COMPANY"
  }
  
  tech_contact = {
    organization_name = "Gildarck"
    first_name       = "Admin"
    last_name        = "Gildarck"
    email            = "admin@gildarck.com"
    phone_number     = "+573213219424"
    address_line_1   = "Calle 123 #45-67"
    city             = "Medellin"
    state            = "Antioquia"
    zip_code         = "050021"
    country_code     = "CO"
    contact_type     = "COMPANY"
  }
  
  # Auto-renewal and privacy settings
  auto_renew = true
  duration_in_years = 1
  privacy_protection = true
}
