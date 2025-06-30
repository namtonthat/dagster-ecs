.PHONY: help install dev stop dev-logs dev-reset build push deploy logs infra-init infra-plan infra-apply infra-destroy create test url

# Infrastructure directory
INFRA_DIR := infrastructure

# AWS Account ID (get from Terraform outputs)
AWS_ACCOUNT_ID := $(shell tofu -chdir=$(INFRA_DIR) output -raw ecr_repository_url | cut -d'.' -f1)

# Default target
help:
	@echo "Available commands:"
	@echo "  Local Development:"
	@echo "    install     - Install Python dependencies with uv"
	@echo "    dev         - Start local Dagster stack with Docker Compose"
	@echo "    stop        - Stop local environment"
	@echo "    dev-logs    - View local logs"
	@echo "    dev-reset   - Reset local database and restart"
	@echo ""
	@echo "  DAG Development:"
	@echo "    create name=<name> - Create new DAG from template"
	@echo "    test        - Run type checking, linting, and tests"
	@echo ""
	@echo "  Deployment:"
	@echo "    build       - Build and tag Docker images"
	@echo "    push        - Push images to ECR"
	@echo "    deploy      - Deploy latest images to ECS Fargate"
	@echo "    logs        - View ECS Fargate logs"
	@echo ""
	@echo "  Infrastructure:"
	@echo "    infra-init    - Initialize OpenTofu backend"
	@echo "    infra-plan    - Preview infrastructure changes"
	@echo "    infra-apply   - Apply infrastructure changes"
	@echo "    infra-destroy - Destroy infrastructure"
	@echo "    url           - Show Dagster web UI URL"

# Local Development
install:
	@echo "Installing Python dependencies..."
	uv sync

dev:
	@echo "Starting local Dagster stack..."
	docker-compose up -d
	@echo "Dagster webserver available at http://localhost:3000"

stop:
	@echo "Stopping local environment..."
	docker-compose down

dev-logs:
	docker-compose logs -f

dev-reset:
	@echo "Resetting local environment..."
	docker-compose down -v
	docker-compose up -d
	@echo "Local environment reset complete"

# Build and deployment (requires AWS CLI and ECR setup)
build:
	@echo "Building Docker image..."
	docker build -f docker/Dockerfile -t dagster-ecs:latest .

push:
	@echo "Pushing to ECR..."
	@echo "Note: Ensure ECR repository exists and AWS CLI is configured"
	aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.ap-southeast-2.amazonaws.com
	docker tag dagster-ecs:latest $(AWS_ACCOUNT_ID).dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest

deploy:
	@echo "Deploying to ECS Fargate..."
	@echo "Note: This requires ECS cluster to be created via infrastructure"
	aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-service-fargate --force-new-deployment

logs:
	@echo "Viewing ECS Fargate logs..."
	aws logs tail /ecs/dagster-ecs-fargate --follow

# Infrastructure management
infra-init:
	@echo "Initializing OpenTofu..."
	tofu -chdir=$(INFRA_DIR) init -upgrade

infra-plan:
	@echo "Planning infrastructure changes..."
	tofu -chdir=$(INFRA_DIR) plan

infra-apply:
	@echo "Applying infrastructure changes..."
	tofu -chdir=$(INFRA_DIR) apply

infra-destroy:
	@echo "Destroying infrastructure..."
	tofu -chdir=$(INFRA_DIR) destroy

# DAG Development
create:
	@if [ -z "$(name)" ]; then \
		echo "Error: name parameter required. Usage: make create name=my_pipeline"; \
		exit 1; \
	fi
	@if [ -f "dags/$(name).py" ]; then \
		echo "Error: DAG $(name).py already exists"; \
		exit 1; \
	fi
	@echo "Creating new DAG: $(name).py"
	@cp templates/dag.py dags/$(name).py
	@sed -i.bak 's/template/$(name)/g' dags/$(name).py
	@rm dags/$(name).py.bak
	@echo "DAG created successfully at dags/$(name).py"
	@echo "Remember to update the asset and job logic for your use case"

test:
	@echo "Running type checking..."
	ty check
	@echo "Running linting..."
	ruff check . --fix
	ruff format .
	@echo "Running tests..."
	pytest

# Infrastructure info
url:
	@echo "Fetching Dagster web UI URL..."
	@tofu -chdir=$(INFRA_DIR) output -raw load_balancer_url

