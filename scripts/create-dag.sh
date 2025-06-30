#!/bin/bash
set -e

# Script to create a new DAG from template
# Usage: ./scripts/create-dag.sh <dag-name>

DAG_NAME="$1"

# Check if dag parameter is provided
if [ -z "$DAG_NAME" ]; then
    echo "Error: dag parameter required. Usage: make create dag=<dag-name>"
    exit 1
fi

# Check if DAG already exists
if [ -f "dags/${DAG_NAME}.py" ]; then
    echo "Error: DAG ${DAG_NAME}.py already exists"
    exit 1
fi

echo "Creating new DAG: ${DAG_NAME}.py"

# Copy template and replace placeholders
cp templates/dag.py "dags/${DAG_NAME}.py"
sed -i.bak "s/template/${DAG_NAME}/g" "dags/${DAG_NAME}.py"
rm "dags/${DAG_NAME}.py.bak"

echo "DAG created successfully at dags/${DAG_NAME}.py"
echo "Remember to update the asset and job logic for your use case"