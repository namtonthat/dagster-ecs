.PHONY: help install start stop logs reset build-local build push deploy-workspace deploy-ecs ecs-logs ecs-status infra-init infra-plan infra-apply infra-destroy create test auth-generate auth-deploy auth-show aws-url aws-account-id aws-credentials

# Infrastructure directory
INFRA_DIR := infrastructure
target := production

# Default target - dynamically generate help from target comments
help: ## Show this help message
	@echo "Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "; category=""} \
		/^##@/ { category=substr($$0,5); print "\n  " category ":"; next } \
		/^[a-zA-Z_-]+:.*?## / { printf "    %-15s %s\n", $$1, $$2 } \
		END { print "" }' $(MAKEFILE_LIST)

##@ Local Development
build-local: ## Build Docker image for local development
	@echo "Building Docker image for local development..."
	docker build --target local -f docker/Dockerfile -t dagster-ecs:local .

install: ## Install Python dependencies with uv
	@echo "Installing Python dependencies..."
	uv sync

logs: ## View local logs
	docker-compose logs -f

start: ## Start local Dagster stack with Docker Compose
	@echo "Starting local Dagster stack..."
	docker-compose up -d --build
	@echo "Dagster webserver available at http://localhost:3000"

stop: ## Stop local environment
	@echo "Stopping local environment..."
	docker-compose down

reset: ## Reset local database and restart
	@echo "Resetting local environment..."
	docker-compose down -v
	docker-compose up -d
	@echo "Local environment reset complete"

##@ Deployment

build: ## Build and tag Docker images
	@echo "Building Docker image for $(target)..."
	docker build --target $(target) -f docker/Dockerfile -t dagster-ecs:latest .

push: ## Build production image and push to ECR
	@echo "Building production Docker image..."
	docker build --target production -f docker/Dockerfile -t dagster-ecs:latest .
	@./scripts/push.sh

deploy-ecs: ## Deploy latest images to ECS Fargate
	@echo "Deploying to ECS Fargate..."
	@echo "Note: This requires ECS cluster to be created via infrastructure"
	aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --force-new-deployment

ecs-logs: ## View ECS Fargate logs
	@echo "Viewing ECS Fargate logs..."
	aws logs tail /ecs/dagster-ecs-fargate --follow

ecs-status: ## Check ECS cluster and service status
	@python scripts/ecs-status.py

ecs-shutdown: ## Shut down ECS cluster while preserving other infrastructure
	@python scripts/ecs-shutdown.py

ecs-recreate: ## Recreate ECS cluster after shutdown
	@python scripts/ecs-recreate.py

##@ Infrastructure

infra-init: ## Initialize OpenTofu backend
	@echo "Initializing OpenTofu..."
	tofu -chdir=$(INFRA_DIR) init -upgrade

infra-plan: ## Preview infrastructure changes
	@echo "Planning infrastructure changes..."
	tofu -chdir=$(INFRA_DIR) plan

infra-apply: ## Apply infrastructure changes
	@echo "Applying infrastructure changes..."
	tofu -chdir=$(INFRA_DIR) apply

infra-destroy: ## Destroy infrastructure
	@echo "Destroying infrastructure..."
	tofu -chdir=$(INFRA_DIR) destroy

##@ DAG Development

create: ## Create new DAG from template (usage: make create dag=my_pipeline)
	@./scripts/create-dag.sh "$(dag)"

test: ## Run type checking, linting, and tests
	@./scripts/test.sh

auth-generate: ## Generate htpasswd entry (usage: make auth-generate user=admin pass=secret)
	@./scripts/manage-auth.sh generate "$(user)" "$(pass)"

auth-deploy: ## Deploy new auth credentials (usage: make auth-deploy user=admin pass=secret)
	@./scripts/manage-auth.sh deploy "$(user)" "$(pass)"

auth-show: ## Show current authentication configuration
	@./scripts/manage-auth.sh show-current

##@ AWS Related Information

aws-url: ## Show how to access Dagster web UI and copy URL to clipboard
	@echo "Fetching Dagster URL..."
	@URL=$$(tofu -chdir=$(INFRA_DIR) output -raw dagster_access_note | grep -o 'http://[^ ]*' | head -1); \
		echo "$$URL"; \
		echo "$$URL" | pbcopy; \
		echo "✓ URL copied to clipboard"

aws-account-id: ## Show AWS Account ID
	@aws sts get-caller-identity --query Account --output text

aws-credentials: ## Show AWS credentials for S3 access (access key + secret key, one per line)
	@tofu -chdir=$(INFRA_DIR) output -raw aws_access_key_id; echo
	@tofu -chdir=$(INFRA_DIR) output -raw aws_secret_access_key; echo

efs-info: ## Show EFS information for external teams
	@echo "EFS Configuration:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ -d "$(INFRA_DIR)" ]; then \
		cd $(INFRA_DIR) && \
		echo "EFS ID: $$(tofu output -raw efs_file_system_id 2>/dev/null || echo 'Not deployed')" && \
		echo "Region: $$(tofu output -raw aws_region 2>/dev/null || echo 'Not deployed')"; \
	else \
		echo "Infrastructure not deployed"; \
	fi

workspace-status: ## Show current workspace configuration and projects
	@echo "Fetching workspace status from EFS..."
	@./scripts/workspace-status.sh

##@ EFS Management

efs-mount: ## Mount EFS locally for direct DAG management
	@echo "Mounting EFS filesystem..."
	@EFS_ID=$$(tofu -chdir=$(INFRA_DIR) output -raw efs_file_system_id 2>/dev/null || echo ""); \
	if [ -z "$$EFS_ID" ]; then \
		echo "❌ Error: EFS not found. Run 'make infra-apply' first"; \
		exit 1; \
	fi; \
	MOUNT_POINT="./efs-mount"; \
	mkdir -p $$MOUNT_POINT; \
	if mount | grep -q $$MOUNT_POINT; then \
		echo "EFS already mounted at $$MOUNT_POINT"; \
	else \
		echo "Installing EFS utilities..."; \
		if ! command -v mount.efs &> /dev/null; then \
			git clone https://github.com/aws/efs-utils /tmp/efs-utils 2>/dev/null || true; \
			cd /tmp/efs-utils && ./build-deb.sh && sudo apt-get install -y ./build/amazon-efs-utils*.deb; \
		fi; \
		sudo mount -t efs -o tls $$EFS_ID:/ $$MOUNT_POINT && \
		echo "✅ EFS mounted at $$MOUNT_POINT"; \
		echo "📁 Access your DAGs at: $$MOUNT_POINT/dagster-workspace/projects/"; \
	fi

efs-unmount: ## Unmount EFS
	@MOUNT_POINT="./efs-mount"; \
	if mount | grep -q $$MOUNT_POINT; then \
		sudo umount $$MOUNT_POINT && \
		echo "✅ EFS unmounted"; \
		rmdir $$MOUNT_POINT 2>/dev/null || true; \
	else \
		echo "EFS not currently mounted"; \
	fi

efs-sync-to-s3: ## Archive current EFS DAGs to S3
	@echo "Archiving DAGs to S3..."
	@MOUNT_POINT="./efs-mount"; \
	if ! mount | grep -q $$MOUNT_POINT; then \
		echo "❌ Error: EFS not mounted. Run 'make efs-mount' first"; \
		exit 1; \
	fi; \
	S3_BUCKET=$$(tofu -chdir=$(INFRA_DIR) output -raw s3_bucket_name 2>/dev/null || echo ""); \
	if [ -z "$$S3_BUCKET" ]; then \
		echo "❌ Error: S3 bucket not found. Run 'make infra-apply' first"; \
		exit 1; \
	fi; \
	TIMESTAMP=$$(date +%Y%m%d-%H%M%S); \
	aws s3 sync $$MOUNT_POINT/dagster-workspace/ s3://$$S3_BUCKET/archive/$$TIMESTAMP/ \
		--exclude "*.pyc" \
		--exclude "__pycache__/*" && \
	echo "✅ Archived to s3://$$S3_BUCKET/archive/$$TIMESTAMP/"

efs-status: ## Show EFS mount status and contents
	@MOUNT_POINT="./efs-mount"; \
	if mount | grep -q $$MOUNT_POINT; then \
		echo "✅ EFS is mounted at $$MOUNT_POINT"; \
		echo ""; \
		echo "📁 Contents:"; \
		ls -la $$MOUNT_POINT/dagster-workspace/projects/ 2>/dev/null || echo "No projects found"; \
	else \
		echo "❌ EFS is not mounted. Run 'make efs-mount' to mount"; \
	fi

