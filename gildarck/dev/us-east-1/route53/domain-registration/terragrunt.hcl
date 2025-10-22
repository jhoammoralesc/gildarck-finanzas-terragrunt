# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Configuration for registering the main domain gildarck.com through Route 53
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "."
}

include "root" {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

generate "main" {
  path      = "main.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
resource "null_resource" "register_domain" {
  provisioner "local-exec" {
    command = <<-EOT
      aws route53domains register-domain \
        --domain-name gildarck.com \
        --duration-in-years 1 \
        --auto-renew \
        --admin-contact OrganizationName=Gildarck,FirstName=Admin,LastName=Gildarck,ContactType=COMPANY,AddressLine1="Calle 123 #45-67",City=Medellin,CountryCode=CO,ZipCode=050021,PhoneNumber=+57.3213219424,Email=admin@gildarck.com \
        --registrant-contact OrganizationName=Gildarck,FirstName=Admin,LastName=Gildarck,ContactType=COMPANY,AddressLine1="Calle 123 #45-67",City=Medellin,CountryCode=CO,ZipCode=050021,PhoneNumber=+57.3213219424,Email=admin@gildarck.com \
        --tech-contact OrganizationName=Gildarck,FirstName=Admin,LastName=Gildarck,ContactType=COMPANY,AddressLine1="Calle 123 #45-67",City=Medellin,CountryCode=CO,ZipCode=050021,PhoneNumber=+57.3213219424,Email=admin@gildarck.com \
        --privacy-protect-admin-contact \
        --privacy-protect-registrant-contact \
        --privacy-protect-tech-contact \
        --profile my-student-user
    EOT
  }

  triggers = {
    domain_name = "gildarck.com"
  }
}

output "domain_name" {
  value = "gildarck.com"
}
EOF
}

inputs = {}
