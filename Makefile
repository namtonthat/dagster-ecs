.PHONY: help dev stop dev-logs dev-reset build push deploy logs infra-init infra-plan infra-apply infra-destroy

# Default target
help:
	@echo "Available commands:"
	@echo "  Local Development:"
	@echo "    dev         - Start local Dagster stack with Docker Compose"
	@echo "    stop        - Stop local environment"
	@echo "    dev-logs    - View local logs"
	@echo "    dev-reset   - Reset local database and restart"
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

# Local Development
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
	cd infrastructure && tofu init

infra-plan:
	@echo "Planning infrastructure changes..."
	cd infrastructure && tofu plan

infra-apply:
	@echo "Applying infrastructure changes..."
	cd infrastructure && tofu apply

infra-destroy:
	@echo "Destroying infrastructure..."
	cd infrastructure && tofu destroy

