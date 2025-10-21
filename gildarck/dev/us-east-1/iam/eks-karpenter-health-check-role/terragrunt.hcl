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
  name         = "eks-karpenter-health-check-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  create_role = true
  role_name   = local.name

  custom_role_trust_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::559756754086:role/eks-karpenter-cleanup",
            "arn:aws:iam::559756754086:role/eks-karpenter-health-check"
          ]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}
