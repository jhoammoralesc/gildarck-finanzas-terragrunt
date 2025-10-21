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
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "eks-ic-api-file-manager-policy"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../s3/ic-${local.vars.ENV}-charge-request-bucket/"
  ]
}


dependency "bucket" {
  config_path = "../../s3/ic-${local.vars.ENV}-charge-request-bucket/"
}

inputs = {
  name        = local.name
  path        = "/"
  description = "Policy to ${local.name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowS3Actions",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::${dependency.bucket.outputs.s3_bucket_id}/*"
        },
        {
            "Sid": "AllowSQsActions",
            "Effect": "Allow",
            "Action": [
                "sqs:sendmessage"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "AllowSecretManagerActions"
        }
    ]
}
EOF
  tags   = local.tags

}