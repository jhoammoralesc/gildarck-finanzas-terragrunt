# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# We override the terraform block source attribute here just for the QA environment to show how you would deploy a
# different version of the module in a specific environment.
# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# We override the terraform block source attribute here just for the QA environment to show how you would deploy a
# different version of the module in a specific environment.
terraform {
  source = "${include.envcommon.locals.base_source_url}"
  before_hook "create_lambda_zip" {
    commands = ["apply"]
    execute  = ["bash", "-c", "cd lambda && python3.9 -m venv .venv && source .venv/bin/activate && pip install kubernetes && cp -r .venv/lib/python3.9/site-packages/kubernetes layers/kubernetes/python/lib/python3.9/site-packages/ && sam deploy --template-file template.yaml --stack-name kubernetes-lambda-layer --capabilities CAPABILITY_NAMED_IAM --resolve-s3 --profile ic-${local.vars.ENV} || true && zip -r ../gildarck-rotate-credentials-function.zip handler.py"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Include configurations that are common used across multiple environments.
# ---------------------------------------------------------------------------------------------------------------------

# Include the root `terragrunt.hcl` configuration. The root configuration contains settings that are common across all
# components and environments, such as how to configure remote state.
include "root" {
  path = find_in_parent_folders()
}

# Include the envcommon configuration for the component. The envcommon configuration contains settings that are common
# for the component across all environments.
include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/lambda/function.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "gildarck-rotate-credentials-function"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  function_name                     = "${local.name}"
  description                       = "Lambda function with database credentials rotation logic."
  handler                           = "handler.lambda_handler"
  runtime                           = "python3.9"
  architectures                     = ["arm64"]
  publish                           = true
  timeout                           = 300
  create_package                    = false
  cloudwatch_logs_retention_in_days = 7
  local_existing_package            = "gildarck-rotate-credentials-function.zip"
  memory_size                       = 1024
  layers                            = ["arn:aws:lambda:${local.tags.region}:${local.aws_account_id}:layer:kubernetes-layer:1"]

  environment_variables = {
    ENV            = local.vars.ENV
    ROLE_TO_ASSUME = "arn:aws:iam::${local.aws_account_id}:role/eks-rotate-credentials-role"
  }

  attach_policy_statements = true
  policy_statements = {
    Eks = {
      effect    = "Allow",
      actions   = ["eks:DescribeCluster", "eks:ListClusters"],
      resources = ["*"]
    },
    SecretsManager = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:ListSecrets"],
      resources = ["*"]
    },
    Rds = {
      effect    = "Allow",
      actions   = ["rds:ModifyDBCluster"],
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
