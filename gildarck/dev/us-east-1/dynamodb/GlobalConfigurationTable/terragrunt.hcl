terraform {
  source = "${include.envcommon.locals.base_source_url}"
}


include "root" {
  path = find_in_parent_folders()
}


include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/dynamodb/table.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "GlobalConfigurationTable"
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  name     = local.name
  hash_key = "id"
  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]
  tags     = local.tags
}