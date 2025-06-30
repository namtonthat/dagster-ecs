#!/bin/bash
set -e

# Basic authentication management script for Dagster

show_help() {
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  generate <username> <password>  - Generate .htpasswd entry"
    echo "  deploy <username> <password>    - Update deployment with new credentials"
    echo "  show-current                    - Show current auth configuration"
    echo ""
    echo "Examples:"
    echo "  $0 generate admin mySecurePass123"
    echo "  $0 deploy admin mySecurePass123"
    echo "  $0 show-current"
}

generate_htpasswd() {
    local username="$1"
    local password="$2"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "❌ Error: Username and password required"
        echo "Usage: $0 generate <username> <password>"
        exit 1
    fi
    
    echo "Generating .htpasswd entry for user: $username"
    echo "$username:$(openssl passwd -apr1 "$password")"
    echo ""
    echo "This entry can be used in nginx .htpasswd file"
}

deploy_credentials() {
    local username="$1"
    local password="$2"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "❌ Error: Username and password required"
        echo "Usage: $0 deploy <username> <password>"
        exit 1
    fi
    
    echo "🔐 Deploying new authentication credentials..."
    echo "Username: $username"
    echo "Password: [hidden]"
    echo ""
    
    # Update infrastructure with new credentials
    cd infrastructure
    
    echo "Updating Terraform variables..."
    tofu apply \
        -var="dagster_auth_user=$username" \
        -var="dagster_auth_password=$password" \
        -auto-approve
    
    echo ""
    echo "✅ Authentication credentials updated successfully!"
    echo "📦 Restart ECS service to apply changes:"
    echo "   make deploy"
}

show_current() {
    echo "🔍 Current authentication configuration:"
    echo ""
    
    cd infrastructure
    
    # Show current username (password is sensitive)
    USERNAME=$(tofu show | grep -A 20 'environment =' | grep 'DAGSTER_AUTH_USER' | awk -F'"' '{print $4}' || echo "Not configured")
    
    echo "Current username: $USERNAME"
    echo "Password: [sensitive - not displayed]"
    echo ""
    echo "To update credentials:"
    echo "  ./scripts/manage-auth.sh deploy <new-username> <new-password>"
}

case "$1" in
    generate)
        generate_htpasswd "$2" "$3"
        ;;
    deploy)
        deploy_credentials "$2" "$3"
        ;;
    show-current)
        show_current
        ;;
    *)
        show_help
        exit 1
        ;;
esac