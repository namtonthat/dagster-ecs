#!/bin/bash
set -e

echo "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Pushing to ECR..."
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com
docker tag dagster-ecs:latest $AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest
