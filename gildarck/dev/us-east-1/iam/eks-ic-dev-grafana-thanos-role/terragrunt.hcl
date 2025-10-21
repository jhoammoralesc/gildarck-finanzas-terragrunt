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
  name         = "eks-ic-dev-grafana-thanos-role"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../eks-ic-dev-grafana-thanos-policy",
    "../../eks/eks-dev-1/"
  ]
}

dependency "eks-ic-dev-grafana-thanos-policy" {
  config_path = "../eks-ic-dev-grafana-thanos-policy"
}

dependency "eks-dev-1" {
  config_path = "../../eks/eks-dev-1/"
}

inputs = {

  create_role = true

  role_name = local.name


  provider_url = dependency.eks-dev-1.outputs.oidc_provider

  role_policy_arns = [
    dependency.eks-ic-dev-grafana-thanos-policy.outputs.arn
  ]

  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]

  oidc_fully_qualified_subjects = ["system:serviceaccount:monitoring:ic-dev-grafana-thanos"]

  tags = local.tags
}