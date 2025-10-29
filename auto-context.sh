#!/bin/bash

# 🤖 AUTO-CONTEXT SYSTEM - Se ejecuta automáticamente
CONTEXT_FILE="/Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/AUTO_CONTEXT.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

# Función para capturar estado completo
capture_state() {
    cat > "$CONTEXT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "session_id": "$(date +%s)",
  "current_directory": "$(pwd)",
  "last_command": "$1",
  "git_status": "$(git status --porcelain 2>/dev/null || echo 'no-git')",
  "aws_profile": "${AWS_PROFILE:-my-student-user}",
  "infrastructure_state": {
    "batch_processor_v2": "$(aws lambda get-function --function-name gildarck-batch-processor-v2-dev --profile my-student-user --query 'Configuration.LastModified' --output text 2>/dev/null || echo 'not-found')",
    "sqs_messages": "$(aws sqs get-queue-attributes --queue-url https://sqs.us-east-1.amazonaws.com/496860676881/gildarck-batch-queue-dev --attribute-names ApproximateNumberOfMessages --profile my-student-user --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null || echo '0')",
    "event_source_mapping": "$(aws lambda get-event-source-mapping --uuid 7561cf5d-6e72-48b1-ad72-f294a57cec58 --profile my-student-user --query 'State' --output text 2>/dev/null || echo 'unknown')"
  },
  "next_actions": [
    "Test batch processor v2 with real SQS message",
    "Validate presigned URL generation", 
    "Check CloudWatch logs for errors",
    "Integrate with frontend React app"
  ],
  "critical_context": {
    "problem_solved": "DynamoDB 400KB limit - storing only metadata now",
    "recent_deployment": "Batch Processor v2 with SQS integration",
    "system_status": "95% complete - needs testing",
    "architecture": "Frontend → Upload-Handler → SQS → Batch-Processor-v2 → URLs"
  }
}
EOF
}

# Capturar estado
capture_state "$@"

# Crear backup con timestamp
cp "$CONTEXT_FILE" "/Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/context-backup-$(date +%s).json"

# Limpiar backups antiguos (mantener solo últimos 10)
ls -t /Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/context-backup-*.json | tail -n +11 | xargs rm -f 2>/dev/null || true
