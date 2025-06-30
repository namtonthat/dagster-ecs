.PHONY: help install start stop logs reset build-local build push deploy-dags deploy-workspace deploy-all deploy ecs-logs infra-init infra-plan infra-apply infra-destroy create test auth-generate auth-deploy auth-show url aws-account-id aws-credentials

# Infrastructure directory
INFRA_DIR := infrastructure

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
	docker-compose up -d
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

build: ## Build and tag Docker images (production target)
	@echo "Building Docker image for production..."
	docker build --target production -f docker/Dockerfile -t dagster-ecs:latest .

push: ## Push images to ECR
	@./scripts/push.sh

deploy-dags: ## Deploy dags to AWS S3
	@echo "Deploying DAGs to S3..."
	./scripts/deploy-dags.sh

deploy-workspace: ## Deploy workspace.yaml to AWS S3
	@echo "Deploying workspace.yaml to S3..."
	./scripts/deploy-workspace.sh

deploy-all: ## Deploy DAGs and workspace to S3, then restart ECS service
	@echo "Deploying all files and restarting ECS service..."
	./scripts/deploy-dags.sh
	./scripts/deploy-workspace.sh
	aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --force-new-deployment

deploy: ## Deploy latest images to ECS Fargate
	@echo "Deploying to ECS Fargate..."
	@echo "Note: This requires ECS cluster to be created via infrastructure"
	aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --force-new-deployment

ecs-logs: ## View ECS Fargate logs
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

auth-generate: ## Generate htpasswd entry (usage: make auth-generate user=admin pass=secret)
	@./scripts/manage-auth.sh generate "$(user)" "$(pass)"

auth-deploy: ## Deploy new auth credentials (usage: make auth-deploy user=admin pass=secret)
	@./scripts/manage-auth.sh deploy "$(user)" "$(pass)"

auth-show: ## Show current authentication configuration
	@./scripts/manage-auth.sh show-current

##@ AWS Related Information

url: ## Show Dagster web UI URL
	@echo "Fetching Dagster web UI URL..."
	@tofu -chdir=$(INFRA_DIR) output -raw load_balancer_url

aws-account-id: ## Show AWS Account ID
	@aws sts get-caller-identity --query Account --output text

aws-credentials: ## Show AWS credentials for S3 access (access key + secret key, one per line)
	@tofu -chdir=$(INFRA_DIR) output -raw aws_access_key_id; echo
	@tofu -chdir=$(INFRA_DIR) output -raw aws_secret_access_key; echo

