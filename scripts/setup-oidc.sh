#!/bin/bash
# ============================================================
# setup-oidc.sh
# Run this ONCE to create the GitHub OIDC provider in AWS.
# Prerequisite: AWS CLI configured with admin permissions.
# ============================================================

set -e

echo "📡 Creating GitHub Actions OIDC provider in AWS..."

aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

echo "✅ OIDC provider created!"
echo ""
echo "Now run Terraform to create all remaining AWS resources:"
echo "  cd terraform"
echo "  terraform init"
echo "  terraform apply -var='github_org=YOUR_GITHUB_USERNAME' -var='github_repo=YOUR_REPO_NAME'"
echo ""
echo "After apply, copy the 'github_actions_role_arn' output and add it"
echo "as secret AWS_ROLE_ARN in your GitHub repository settings."
