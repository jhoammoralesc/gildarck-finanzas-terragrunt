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
  name         = "eks-ic-api-rtp-manager-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../eks-ic-api-rtp-manager-policy",
    "../../eks/eks-${local.vars.ENV}-1/"
  ]
}

dependency "policy" {
  config_path = "../eks-ic-api-rtp-manager-policy"
}

dependency "eks" {
  config_path = "../../eks/eks-${local.vars.ENV}-1/"
}

inputs = {

  create_role = true

  role_name = local.name


  provider_url = dependency.eks.outputs.oidc_provider

  role_policy_arns = [
    dependency.policy.outputs.arn
  ]

  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]

  oidc_fully_qualified_subjects = ["system:serviceaccount:gildarck-${local.vars.ENV}:ic-api-rtp-manager"]

  tags = local.tags
}