#!/bin/bash

# GILDARCK Rollback Script
# Restores resources if optimization causes issues

set -e

echo "🔄 GILDARCK Rollback - Restoring resources"
echo ""

export AWS_PROFILE=my-student-user
cd /Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/gildarck/dev/us-east-1

echo "1️⃣ Restoring NAT Gateway..."
# Restore env.hcl NAT Gateway setting
sed -i '' 's/ENABLE_NAT_GATEWAY       = false/ENABLE_NAT_GATEWAY       = true/' ../../env.hcl
sed -i '' 's/SINGLE_NAT_GATEWAY       = false/SINGLE_NAT_GATEWAY       = true/' ../../env.hcl

cd vpc/network-1
terragrunt apply --terragrunt-non-interactive
cd ../..

echo "2️⃣ Restoring WAF..."
cd waf/waf-fronted
terragrunt apply --terragrunt-non-interactive
cd ../..

echo ""
echo "✅ Rollback completed!"
echo "💰 Cost restored to: $52.25/month"
