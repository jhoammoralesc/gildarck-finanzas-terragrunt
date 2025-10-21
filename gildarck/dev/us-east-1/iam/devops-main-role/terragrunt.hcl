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
  name         = "devops-main-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../../../shared/us-east-1/iam/github-oidc-role"
  ]
}

dependency "github-oidc-role" {
  config_path = "../../../../shared/us-east-1/iam/github-oidc-role"
}

inputs = {

  create_role = true

  role_name = local.name

  attach_admin_policy = true

  custom_role_trust_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${dependency.github-oidc-role.outputs.iam_role_arn}"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

  tags = local.tags
}
