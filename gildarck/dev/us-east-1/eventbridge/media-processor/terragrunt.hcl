terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/eventbridge/rule.hcl"
  expose = true
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name = "media-processor-s3-events"
}

dependencies {
  paths = [
    "../../lambda/media-processor"
  ]
}

dependency "lambda" {
  config_path = "../../lambda/media-processor"
}

inputs = {
  create_bus = false
  role_name = "media-processor-eventbridge"
  rules = {
    media-processor = {
      description = "Rule triggered when files are created in the media storage S3 bucket"
      event_pattern = jsonencode({
        "source": ["aws.s3"],
        "detail-type": ["Object Created"],
        "detail": {
          "bucket": {
            "name": ["gildarck-media-dev"]
          }
        }
      })
    }
  }

  targets = {
    media-processor = [
      {
        name = "ProcessMediaFiles"
        arn  = dependency.lambda.outputs.lambda_function_arn
      }
    ]
  }
}
