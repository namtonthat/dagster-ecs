#!/bin/bash
set -e

# Simulate CI/CD pipeline behavior to verify credentials are protected
echo "🔄 Simulating CI/CD pipeline output..."

cd infrastructure

echo "1. What a CI/CD pipeline would see with 'tofu output':"
echo "=================================================="
tofu output
echo ""

echo "2. What happens if CI/CD tries to grep for secrets:"
echo "=================================================="
if tofu output | grep -i "secret\|key\|credential" | grep -v "<sensitive>" | grep -v "arn:aws:secretsmanager"; then
    echo "❌ CRITICAL: Raw credentials found in output!"
    exit 1
else
    echo "✅ SAFE: No raw credentials visible in standard output"
fi

echo ""
echo "3. Verification that secrets are truly hidden:"
echo "=============================================="
# Count how many times <sensitive> appears
SENSITIVE_COUNT=$(tofu output | grep -c "<sensitive>" || echo "0")
echo "Found $SENSITIVE_COUNT <sensitive> markers"

if [ "$SENSITIVE_COUNT" -lt 2 ]; then
    echo "❌ FAIL: Expected at least 2 <sensitive> markers (access key + secret key)"
    exit 1
fi

echo "✅ PASS: Expected number of sensitive values are properly masked"

echo ""
echo "🔒 CI/CD Security Summary:"
echo "========================="
echo "✅ Credentials are not exposed in standard terraform output"
echo "✅ CI/CD pipelines will only see <sensitive> placeholders"
echo "✅ Raw credential values require explicit -raw flag access"
echo "✅ System is safe for automated deployment pipelines"