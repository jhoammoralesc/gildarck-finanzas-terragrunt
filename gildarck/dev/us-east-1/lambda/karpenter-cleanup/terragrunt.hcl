terraform {
  source = "${include.envcommon.locals.base_source_url}"
  before_hook "create_lambda_zip" {
    commands = ["apply"]
    execute  = ["bash", "-c", "cd . && zip -r karpenter-cleanup.zip handler.py"]
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
  name           = "eks-karpenter-cleanup"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  function_name                     = "${local.name}"
  description                       = "Clean up Karpenter finalizers for NotReady nodes and orphaned NodeClaims"
  handler                           = "handler.lambda_handler"
  runtime                           = "python3.12"
  architectures                     = ["x86_64"]
  publish                           = true
  timeout                           = 300
  create_package                    = false
  cloudwatch_logs_retention_in_days = 7
  local_existing_package            = "karpenter-cleanup.zip"
  memory_size                       = 512
  layers                            = ["arn:aws:lambda:${local.tags.region}:${local.aws_account_id}:layer:karpenter-dependencies:2"]

  environment_variables = {
    CLUSTER_NAME   = "eks-dev-1"
    ROLE_TO_ASSUME = "arn:aws:iam::${local.aws_account_id}:role/eks-karpenter-health-check-role"
  }

  attach_policy_statements = true
  policy_statements = {
    Eks = {
      effect    = "Allow",
      actions   = ["eks:DescribeCluster", "eks:ListClusters"],
      resources = ["*"]
    },
    Sts = {
      effect    = "Allow",
      actions   = ["sts:AssumeRole"],
      resources = ["arn:aws:iam::${local.aws_account_id}:role/eks-karpenter-health-check-role"]
    }
  }

  tags = local.tags
}
