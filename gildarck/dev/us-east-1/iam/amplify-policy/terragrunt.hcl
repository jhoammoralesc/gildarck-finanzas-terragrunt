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
  name         = "amplify-policy"
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
        "Sid" : "AllowCloudWatchActions"
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowParameterStoreActions"
        "Action" : [
          "ssm:GetParametersByPath",
          "ssm:GetParameters"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:PutItem"
        ],
        "Resource": "*"
      }
    ]
  })

}
