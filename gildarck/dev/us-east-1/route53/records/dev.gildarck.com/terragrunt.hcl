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
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/route53/records.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "${local.vars.ENV}.gildarck.com"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

dependencies {
  paths = [
    "../../zones/${local.vars.ENV}.gildarck.com",
    # "../../../rds/aurora-serverless-${local.vars.ENV}-postgresql-chat",
    "../../../cloudfront/${local.vars.ENV}.gildarck.com"
  ]
}

dependency "zones" {
  config_path = "../../zones/${local.vars.ENV}.gildarck.com"
  #skip_outputs = true
}

# dependency "rds-chat" {
#   config_path = "../../../rds/aurora-serverless-${local.vars.ENV}-postgresql-chat"
# }

dependency "cloudfront" {
  config_path = "../../../cloudfront/${local.vars.ENV}.gildarck.com"
}

# ---------------------------------------------------------------------------------------------------------------------
# We don't need to override any of the common parameters for this environment, so we don't specify any inputs.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {


  zone_name = keys(dependency.zones.outputs.route53_zone_zone_id)[0]

  records = [
    {
      name = ""
      type = "A"
      alias = {
        name                   = dependency.cloudfront.outputs.cloudfront_distribution_domain_name
        zone_id                = dependency.cloudfront.outputs.cloudfront_distribution_hosted_zone_id
        evaluate_target_health = false
      }
    },
    # {
    #   name = ""
    #   type = "TXT"
    #   ttl  = 60
    #   records = [
    #     "v=spf1 include:_spf.firebasemail.com include:amazonses.com ~all",
    #     "firebase=gildarckdes"
    #   ]
    # },
    # {
    #   name = "${split(".", dependency.acm.outputs.acm_certificate_domain_validation_options[0].resource_record_name)[0]}"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "${dependency.acm.outputs.acm_certificate_domain_validation_options[0].resource_record_value}"
    #   ]
    # },
    # {
    #   name = "firebase1._domainkey"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "mail-dev-gildarck-com.dkim1._domainkey.firebasemail.com."
    #   ]
    # },
    # {
    #   name = "firebase2._domainkey"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "mail-dev-gildarck-com.dkim2._domainkey.firebasemail.com."
    #   ]
    # },
    # {
    #   name = "mysql"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds.outputs.cluster_endpoint
    #   ]
    # },
    # {
    #   name = "rw.mysql-core"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds.outputs.cluster_endpoint
    #   ]
    # },
    # {
    #   name = "ro.mysql-core"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds.outputs.cluster_reader_endpoint
    #   ]
    # },
    # {
    #   name = "rw.mysql-fm"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-fm.outputs.cluster_endpoint
    #   ]
    # },
    # {
    #   name = "ro.mysql-fm"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-fm.outputs.cluster_reader_endpoint
    #   ]
    # },
    # {
    #   name = "rw.mysql-flexibility"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-flexibility.outputs.cluster_endpoint
    #   ]
    # },
    # {
    #   name = "ro.mysql-flexibility"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-flexibility.outputs.cluster_reader_endpoint
    #   ]
    # },
    # {
    #   name = "rw.mysql-ia"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-speedboat-ia.outputs.cluster_endpoint
    #   ]
    # },
    # {
    #   name = "ro.mysql-ia"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-speedboat-ia.outputs.cluster_reader_endpoint
    #   ]
    # },
    # {
    #   name = "api"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d31a5mqssfe6v5.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "api.bo"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d9ji626zy78g7.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "api.rtp"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d1b833cgpsaw0t.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "api.flexi"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d16ci5m9bczmb2.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "k8s"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "a0f15b6056ef44545993d99cc5f1b38e-bff40da06b806282.elb.us-east-1.amazonaws.com"
    #   ]
    # },
    # {
    #   name = "grafana"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "a0f15b6056ef44545993d99cc5f1b38e-bff40da06b806282.elb.us-east-1.amazonaws.com"
    #   ]
    # },
    # {
    #   name = "thanos-query"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "a0f15b6056ef44545993d99cc5f1b38e-bff40da06b806282.elb.us-east-1.amazonaws.com"
    #   ]
    # },
    # {
    #   name = "ynl6gloeovtszqubp2f6fmp4andpu2f3._domainkey"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "ynl6gloeovtszqubp2f6fmp4andpu2f3.dkim.amazonses.com"
    #   ]
    # },
    # {
    #   name = "irohaozvwr5xomjjrzhgegp4q76zs7fg._domainkey"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "irohaozvwr5xomjjrzhgegp4q76zs7fg.dkim.amazonses.com"
    #   ]
    # },
    # {
    #   name = "jmihyg7sogj6nkhw3pva3g7zdxz3hhzg._domainkey"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "jmihyg7sogj6nkhw3pva3g7zdxz3hhzg.dkim.amazonses.com"
    #   ]
    # },
    # {
    #   name = "_dmarc"
    #   type = "TXT"
    #   ttl  = 60
    #   records = [
    #     "v=DMARC1; p=none; rua=mailto:intercobros.cloud.dev@gmail.com; ruf=mailto:intercobros.cloud.dev@gmail.com"
    #   ]
    # },
    # {
    #   name = "kafka-ui"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "a0f15b6056ef44545993d99cc5f1b38e-bff40da06b806282.elb.us-east-1.amazonaws.com"
    #   ]
    # }
    # {
    #   name = "apim"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d14r8qel7fqmph.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "gildarck.apim"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d1x4366wdckcrr.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "rtp.apim"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d1fplpenmpqf4.cloudfront.net"
    #   ]
    # },
    # {
    #   name = "rw.psgql-chat"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-chat.outputs.cluster_endpoint
    #   ]
    # },
    # {
    #   name = "ro.psgql-chat"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     dependency.rds-chat.outputs.cluster_reader_endpoint
    #   ]
    # },
    # {
    #   name = "synapse"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d-4otmey8zkl.execute-api.us-east-1.amazonaws.com"
    #   ]
    # },
    # {
    #   name = "ai.apim"
    #   type = "CNAME"
    #   ttl  = 60
    #   records = [
    #     "d1bi4owkhpy10c.cloudfront.net"
    #   ]
    # }
  ]

}