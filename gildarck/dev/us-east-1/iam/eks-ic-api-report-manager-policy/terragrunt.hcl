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
  name         = "eks-ic-api-report-manager-policy"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../s3/ic-${local.vars.ENV}-renditions/",
    "../../s3/ic-${local.vars.ENV}-exportations/",
    "../../s3/ic-${local.vars.ENV}-coupons/"
  ]
}

dependency "bucket" {
  config_path = "../../s3/ic-${local.vars.ENV}-renditions/"
}

dependency "bucket_2" {
  config_path = "../../s3/ic-${local.vars.ENV}-exportations/"
}

dependency "bucket_3" {
  config_path = "../../s3/ic-${local.vars.ENV}-coupons/"
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
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${dependency.bucket.outputs.s3_bucket_id}/*",
                "arn:aws:s3:::${dependency.bucket_2.outputs.s3_bucket_id}/*",
                "arn:aws:s3:::${dependency.bucket_3.outputs.s3_bucket_id}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${dependency.bucket.outputs.s3_bucket_id}",
                "arn:aws:s3:::${dependency.bucket_2.outputs.s3_bucket_id}",
                "arn:aws:s3:::${dependency.bucket_3.outputs.s3_bucket_id}"
            ]
        },
        {
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "AllowSecretManagerActions"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendTemplatedEmail",
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "*",
            "Sid": "AllowSESActions"
        }
    ]
}
EOF

  tags = local.tags

}
