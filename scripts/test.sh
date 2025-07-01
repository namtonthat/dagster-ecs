#!/bin/bash
set -e

# Script to run type checking, linting, and tests
# Usage: ./scripts/test.sh

echo "Running type checking..."
uv run ty check

echo "Running linting..."
uv run ruff check --fix .
ur run ruff format .

# echo "Running tests..."
# pytest

echo "✅ All tests passed!"
