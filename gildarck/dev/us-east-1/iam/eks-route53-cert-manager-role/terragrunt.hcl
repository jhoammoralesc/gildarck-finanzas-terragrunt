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
  name         = "eks-route53-cert-manager-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../eks-route53-cert-manager-policy",
    "../../eks/eks-${local.vars.ENV}-1/"
  ]
}

dependency "eks-route53-cert-manager-policy" {
  config_path = "../eks-route53-cert-manager-policy"
}

dependency "eks" {
  config_path = "../../eks/eks-${local.vars.ENV}-1/"
}

inputs = {

  create_role = true

  role_name = local.name


  provider_url = dependency.eks.outputs.oidc_provider

  role_policy_arns = [
    dependency.eks-route53-cert-manager-policy.outputs.arn
  ]

  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]

  oidc_fully_qualified_subjects = ["system:serviceaccount:cert-manager:cert-manager"]

  tags = local.tags
}