terraform {
  source = "${include.envcommon.locals.base_source_url}"
}


include "root" {
  path = find_in_parent_folders()
}


include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/iam/user.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "rtp-manager-user"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  name        = local.name
  user_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Actions",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::ic-${local.vars.ENV}-rtp-business-reports/*"
    }
  ]
}
EOF
  tags        = local.tags
}