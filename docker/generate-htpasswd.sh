#!/bin/bash
set -e

# Generate .htpasswd file for nginx basic auth
# Usage: ./generate-htpasswd.sh username password

USERNAME="${1:-admin}"
PASSWORD="${2:-dagster123}"

# Use openssl to generate bcrypt hash (more secure than MD5)
echo "Generating .htpasswd for user: $USERNAME"
echo "$USERNAME:$(openssl passwd -apr1 "$PASSWORD")" > /tmp/.htpasswd

echo "Generated .htpasswd file:"
cat /tmp/.htpasswd
echo ""
echo "Copy this content to your .htpasswd file or AWS Secrets Manager"