terraform {
  source = "${include.envcommon.locals.base_source_url}"
}

include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/aws/sqs/sqs.hcl"
  expose = true
}

locals {
  vars         = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name         = "gildarck-batch-queue"
  service_vars = read_terragrunt_config(find_in_parent_folders("service.hcl"))
  tags         = merge(local.service_vars.locals.tags, { name = local.name })
}

inputs = {
  name = "${local.name}-dev"
  
  # Queue configuration
  visibility_timeout_seconds = 900  # 15 minutes
  message_retention_seconds = 1209600  # 14 days
  max_message_size = 262144  # 256KB
  delay_seconds = 0
  receive_wait_time_seconds = 20  # Long polling
  
  # Dead Letter Queue
  create_dlq = true
  dlq_name = "${local.name}-dev-dlq"
  max_receive_count = 3
  
  # Redrive policy
  redrive_policy = {
    deadLetterTargetArn = "arn:aws:sqs:us-east-1:496860676881:${local.name}-dev-dlq"
    maxReceiveCount = 3
  }
  
  tags = merge(local.tags, {
    Component = "batch-processing"
    Purpose = "batch-upload-queue"
  })
}
