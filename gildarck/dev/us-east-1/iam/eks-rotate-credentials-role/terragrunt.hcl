terraform {
  source = "${include.envcommon.locals.base_source_url}"
}


include "root" {
  path = find_in_parent_folders()
}


include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/iam/assumable-role.hcl"
  expose = true
}

locals {
  name         = "eks-rotate-credentials-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../eks-rotate-credentials-policy"
  ]
}

dependency "policy" {
  config_path = "../eks-rotate-credentials-policy"
}

inputs = {

  create_role = true

  role_name = local.name

  role_policy_arns = [
    dependency.policy.outputs.arn
  ]

  custom_role_trust_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "lambda.amazonaws.com"
            ]
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )

  tags = local.tags
}
