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
  name         = "eks-ic-audit-connector-policy"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
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
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "AllowSecretManagerActions"
        },
        {
            "Action": [
                "kafka-cluster:Connect",
                "kafka-cluster:*Topic*",
                "kafka-cluster:WriteData",
                "kafka-cluster:ReadData",
                "kafka-cluster:DescribeCluster",
                "kafka-cluster:AlterGroup",
                "kafka-cluster:DescribeGroup"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "AllowMSKActions"
        }
    ]
}
EOF

  tags = local.tags

}