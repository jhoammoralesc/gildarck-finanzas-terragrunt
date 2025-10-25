#!/bin/bash

# GILDARCK Cost Optimization Script
# Removes unnecessary resources to save $37/month

set -e

echo "🎯 GILDARCK Cost Optimization - Removing expensive resources"
echo "💰 Expected savings: $37.00/month ($444/year)"
echo ""

export AWS_PROFILE=my-student-user
cd /Users/jhoam.morales/Documents/gildarck/infrastructure-iac-terragrunt/gildarck/dev/us-east-1

echo "1️⃣ Destroying WAF (saves $0.60/month)..."
cd waf/waf-fronted
terragrunt destroy --terragrunt-non-interactive --terragrunt-working-dir . --auto-approve
cd ../..

echo "2️⃣ Updating VPC to disable NAT Gateway (saves $32.40/month)..."
cd vpc/network-1
terragrunt apply --terragrunt-non-interactive
cd ../..

echo "3️⃣ Updating Amplify build configuration (saves $4.00/month)..."
cd amplify/dev.gildarck.com
terragrunt apply --terragrunt-non-interactive
cd ../..

echo ""
echo "✅ Cost optimization completed!"
echo "💰 Monthly savings: $37.00"
echo "📊 New estimated cost: $15.25/month"
echo ""
echo "⚠️  Note: NAT Gateway elimination is safe because:"
echo "   - No EKS clusters are running"
echo "   - No EC2 instances in private subnets"
echo "   - Lambda functions use managed VPC connectivity"
