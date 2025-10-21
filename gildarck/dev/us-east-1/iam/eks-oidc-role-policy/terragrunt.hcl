terraform {
  source = "${include.envcommon.locals.base_source_url}"
}


include "root" {
  path = find_in_parent_folders()
}


include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/iam/policy.hcl"
  expose = true
}

locals {
  name         = "eks-oidc-role-policy"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  name        = local.name
  path        = "/"
  description = "Policy to ${local.name}"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "sts:AssumeRole",
          "sts:AssumeRoleWithWebIdentity"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })

}
