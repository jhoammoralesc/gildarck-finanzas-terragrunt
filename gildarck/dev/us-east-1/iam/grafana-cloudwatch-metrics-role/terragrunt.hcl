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
  name         = "grafana-cloudwatch-metrics-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {

  create_role = true

  role_name = local.name

  custom_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonGrafanaCloudWatchAccess"]

  custom_role_trust_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::477025688834:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

  tags = local.tags
}
