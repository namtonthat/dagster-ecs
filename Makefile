.PHONY: help install dev stop dev-logs dev-reset build push deploy-dags deploy deploy-all logs infra-init infra-plan infra-apply infra-destroy create test url

# Infrastructure directory
INFRA_DIR := infrastructure

# AWS Account ID (get from Terraform outputs)
AWS_ACCOUNT_ID := $(shell tofu -chdir=$(INFRA_DIR) output -raw ecr_repository_url | cut -d'.' -f1)

# Default target - dynamically generate help from target comments
help: ## Show this help message
	@echo "Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "; category=""} \
		/^##@/ { category=substr($$0,5); print "\n  " category ":"; next } \
		/^[a-zA-Z_-]+:.*?## / { printf "    %-15s %s\n", $$1, $$2 } \
		END { print "" }' $(MAKEFILE_LIST)

##@ Local Development

install: ## Install Python dependencies with uv
	@echo "Installing Python dependencies..."
	uv sync

dev: ## Start local Dagster stack with Docker Compose
	@echo "Starting local Dagster stack..."
	docker-compose up -d
	@echo "Dagster webserver available at http://localhost:3000"

stop: ## Stop local environment
	@echo "Stopping local environment..."
	docker-compose down

dev-logs: ## View local logs
	docker-compose logs -f

dev-reset: ## Reset local database and restart
	@echo "Resetting local environment..."
	docker-compose down -v
	docker-compose up -d
	@echo "Local environment reset complete"

##@ Deployment

build: ## Build and tag Docker images (runtime only)
	@echo "Building Docker image..."
	docker build -f docker/Dockerfile -t dagster-ecs:latest .

push: ## Push images to ECR
	@echo "Pushing to ECR..."
	@echo "Note: Ensure ECR repository exists and AWS CLI is configured"
	aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.ap-southeast-2.amazonaws.com
	docker tag dagster-ecs:latest $(AWS_ACCOUNT_ID).dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest

deploy-dags: ## Upload DAG files to S3 (fast deployment)
	@echo "Deploying DAGs to S3..."
	./scripts/deploy-dags.sh

deploy: ## Deploy latest images to ECS Fargate
	@echo "Deploying to ECS Fargate..."
	@echo "Note: This requires ECS cluster to be created via infrastructure"
	aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --force-new-deployment

deploy-all: deploy-dags deploy ## Upload DAGs and restart ECS service
	@echo "✅ Full deployment complete - DAGs uploaded to S3 and ECS service restarted"

logs: ## View ECS Fargate logs
	@echo "Viewing ECS Fargate logs..."
	aws logs tail /ecs/dagster-ecs-fargate --follow

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

security-check: ## Run security assertions for AWS credentials
	@./scripts/security-check.sh

##@ Information

url: ## Show Dagster web UI URL
	@echo "Fetching Dagster web UI URL..."
	@tofu -chdir=$(INFRA_DIR) output -raw load_balancer_url

aws-credentials: ## Show AWS credentials for S3 access
	@tofu -chdir=$(INFRA_DIR) output -raw aws_access_key_id; echo
	@tofu -chdir=$(INFRA_DIR) output -raw aws_secret_access_key; echo

