# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
  service     = "apigateway"
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  tags        = merge(local.region_vars.locals.tags, { service = local.service })

}
