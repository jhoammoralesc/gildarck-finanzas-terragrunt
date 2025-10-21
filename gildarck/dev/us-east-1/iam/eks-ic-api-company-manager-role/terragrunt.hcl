terraform {
  source = "${include.envcommon.locals.base_source_url}"
}


include "root" {
  path = find_in_parent_folders()
}


include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/iam/assumable-role-with-oidc.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "eks-ic-api-company-manager-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../eks-ic-api-company-manager-policy",
    "../../eks/eks-${local.vars.ENV}-1/"
  ]
}

dependency "eks-ic-api-company-manager-policy" {
  config_path = "../eks-ic-api-company-manager-policy"
}

dependency "eks" {
  config_path = "../../eks/eks-${local.vars.ENV}-1/"
}

inputs = {

  create_role = true

  role_name = local.name


  provider_url = dependency.eks.outputs.oidc_provider

  role_policy_arns = [
    dependency.eks-ic-api-company-manager-policy.outputs.arn
  ]

  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]

  oidc_fully_qualified_subjects = ["system:serviceaccount:gildarck-${local.vars.ENV}:ic-api-company-manager"]

  tags = local.tags
}