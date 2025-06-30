#!/bin/bash
set -e

# Security assertions script
# Verifies that AWS credentials are properly protected

echo "🔒 Running security assertions..."

# Change to infrastructure directory
cd infrastructure

echo "1. Checking that AWS credentials are marked as sensitive in Terraform outputs..."

# Check that aws_access_key_id is marked as sensitive
if ! grep -A 5 'output "aws_access_key_id"' iam.tf | grep -q 'sensitive.*=.*true'; then
    echo "❌ FAIL: aws_access_key_id is not marked as sensitive"
    exit 1
fi

# Check that aws_secret_access_key is marked as sensitive
if ! grep -A 5 'output "aws_secret_access_key"' iam.tf | grep -q 'sensitive.*=.*true'; then
    echo "❌ FAIL: aws_secret_access_key is not marked as sensitive"
    exit 1
fi

echo "✅ PASS: Both AWS credentials are marked as sensitive in Terraform"

echo "2. Checking that Terraform output shows credentials as <sensitive>..."

# Check that tofu output shows credentials as sensitive
if ! tofu output | grep -q "aws_access_key_id = <sensitive>"; then
    echo "❌ FAIL: aws_access_key_id is not showing as <sensitive> in output"
    exit 1
fi

if ! tofu output | grep -q "aws_secret_access_key = <sensitive>"; then
    echo "❌ FAIL: aws_secret_access_key is not showing as <sensitive> in output"
    exit 1
fi

echo "✅ PASS: Terraform outputs show credentials as <sensitive>"

echo "3. Checking that manual access still works with -raw flag..."

# Check that we can still access the values when needed
ACCESS_KEY=$(tofu output -raw aws_access_key_id)
SECRET_KEY=$(tofu output -raw aws_secret_access_key)

if [ -z "$ACCESS_KEY" ] || [ ${#ACCESS_KEY} -lt 10 ]; then
    echo "❌ FAIL: Could not retrieve access key or it's too short"
    exit 1
fi

if [ -z "$SECRET_KEY" ] || [ ${#SECRET_KEY} -lt 10 ]; then
    echo "❌ FAIL: Could not retrieve secret key or it's too short"
    exit 1
fi

echo "✅ PASS: Credentials can still be accessed when needed with -raw flag"

echo "4. Checking DDoS protection configuration..."

# Check that auto-scaling is limited to prevent DDoS attacks
MAX_CAPACITY=$(grep -A 3 "max_capacity" ecs_fargate.tf | grep "max_capacity" | awk '{print $3}')
if [ "$MAX_CAPACITY" -ne 2 ]; then
    echo "❌ FAIL: Max capacity should be 2 for DDoS protection, found $MAX_CAPACITY"
    exit 1
fi

echo "✅ PASS: DDoS protection verified - auto-scaling limited to 2 instances maximum"

echo "5. Checking basic authentication configuration..."

# Check that auth variables are properly defined
if ! grep -q "dagster_auth_user" variables.tf; then
    echo "❌ FAIL: dagster_auth_user variable not found in variables.tf"
    exit 1
fi

if ! grep -q "dagster_auth_password" variables.tf; then
    echo "❌ FAIL: dagster_auth_password variable not found in variables.tf"
    exit 1
fi

if ! grep -A 5 'dagster_auth_password' variables.tf | grep -q 'sensitive.*=.*true'; then
    echo "❌ FAIL: dagster_auth_password is not marked as sensitive"
    exit 1
fi

echo "✅ PASS: Basic authentication variables properly configured"

echo ""
echo "🔒 All security assertions passed!"
echo "✅ AWS credentials are properly protected from CI/CD exposure"
echo "✅ Credentials are marked as sensitive in Terraform"
echo "✅ Credentials show as <sensitive> in normal output"
echo "✅ Credentials can still be accessed when explicitly needed"
echo "✅ DDoS protection configured - scaling limited to 2 instances"
echo "✅ Basic authentication properly configured with sensitive password"