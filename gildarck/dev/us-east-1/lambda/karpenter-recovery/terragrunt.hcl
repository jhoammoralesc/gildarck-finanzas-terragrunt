terraform {
  source = "${include.envcommon.locals.base_source_url}"
  before_hook "create_lambda_zip" {
    commands = ["apply"]
    execute  = ["bash", "-c", "cd . && zip -r karpenter-recovery.zip handler.py"]
  }
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/lambda/function.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "karpenter-recovery"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name                     = "${local.name}"
  description                       = "Scale nodegroup and restart Karpenter deployment"
  handler                           = "handler.lambda_handler"
  runtime                           = "python3.12"
  architectures                     = ["arm64"]
  publish                           = true
  timeout                           = 300
  create_package                    = false
  cloudwatch_logs_retention_in_days = 7
  local_existing_package            = "karpenter-recovery.zip"
  memory_size                       = 512
  layers                            = ["arn:aws:lambda:${local.tags.region}:${local.aws_account_id}:layer:kubernetes-layer:1"]

  environment_variables = {
    CLUSTER_NAME     = "eks-dev-1"
    ROLE_TO_ASSUME   = "arn:aws:iam::${local.aws_account_id}:role/eks-rotate-credentials-role"
    NODE_GROUP_NAME  = "non-fargate-20250804141603154100000001"
  }

  attach_policy_statements = true
  policy_statements = {
    Eks = {
      effect    = "Allow",
      actions   = ["eks:DescribeCluster", "eks:ListClusters", "eks:DescribeNodegroup", "eks:UpdateNodegroupConfig"],
      resources = ["*"]
    },
    Autoscaling = {
      effect    = "Allow",
      actions   = ["autoscaling:UpdateAutoScalingGroup", "autoscaling:DescribeAutoScalingGroups"],
      resources = ["*"]
    },
    Sts = {
      effect    = "Allow",
      actions   = ["sts:AssumeRole"],
      resources = ["arn:aws:iam::${local.aws_account_id}:role/eks-rotate-credentials-role"]
    }
  }

  tags = local.tags
}
