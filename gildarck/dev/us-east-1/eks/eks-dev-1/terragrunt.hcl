# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# We override the terraform block source attribute here just for the QA environment to show how you would deploy a
# different version of the module in a specific environment.
terraform {
  source = "${include.envcommon.locals.base_source_url}"
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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/eks/cluster.hcl"
  expose = true
}

locals {
  vars           = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name           = "eks-${local.vars.ENV}-1"
  aws_account_id = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals.aws_account_id
  service_vars   = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  namespaces     = ["ic-${local.vars.ENV}"]
  tags           = merge(local.service_vars.locals.tags, { name = local.name })
}

generate "provider-local" {
  path      = "provider-local.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF

    provider "kubernetes" {
      alias                  = "devops-kubernetes"
      host                   = output.host
      cluster_ca_certificate = base64decode(output.cluster_ca_certificate)
      token                  = output.token
  }
    
EOF
}

dependencies {
  paths = ["../../vpc/network-1", "../../iam/eks-karpenter-node-role"]
}

dependency "vpc" {
  config_path = "../../vpc/network-1"
  #skip_outputs = true
}

dependency "node-role" {
  config_path = "../../iam/eks-karpenter-node-role"
  #skip_outputs = true
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  cluster_name                    = "${local.name}"
  cluster_version                 = "1.33"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_delete_timeout        = "30m"
  cluster_iam_role_name         = "${local.name}-cluster-role"
  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_log_retention_in_days = 7

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  cluster_addons = {
    coredns = {
      addon_version     = "v1.12.2-eksbuild.4"
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      addon_version     = "v1.33.0-eksbuild.2"
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      addon_version     = "v1.19.6-eksbuild.7"
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      addon_version            = "v1.45.0-eksbuild.2"
      service_account_role_arn = "arn:aws:iam::${local.aws_account_id}:role/eks-ebs-csi-controller-role"
      resolve_conflicts        = "OVERWRITE"
    }
    // aws-guardduty-agent = {
    //   addon_version     = "v1.7.1-eksbuild.2"
    //   resolve_conflicts = "OVERWRITE"
    // }

  }

  eks_managed_node_group_defaults = {
    disk_size      = 50
    instance_types = ["t3a.large"]
    security_group_rules = {
      egress_allow_all = {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = ["0.0.0.0/0"]
        type        = "egress"
      }
      ingress_allow_local = {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = [dependency.vpc.outputs.vpc_cidr_block]
        type        = "ingress"
      }
    }
  }

  node_security_group_tags = merge(local.tags,
    {
      "karpenter.sh/discovery" = local.name
    }
  )

  aws_auth_roles = [
    {
      rolearn  = dependency.node-role.outputs.iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]

  # fargate_profiles = {
  #   karpenter = {
  #     name = "karpenter"
  #     selectors = [
  #       {
  #         namespace = "karpenter"
  #       }
  #     ]
  #   }
  # }

  eks_managed_node_groups = {
    non-fargate = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3a.large"]
      capacity_type  = "ON_DEMAND"
      taints = [
        {
          key    = "CriticalAddonsOnly"
          value  = ""
          effect = "NO_SCHEDULE"
        }
      ]
      labels = {
        "karpenter.sh/controller" = "karpenter"
      }
    }
  }

  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      source_cluster_security_group = true
      description                   = "Allow access from control plane"
    }
  }

  tags = local.tags
}