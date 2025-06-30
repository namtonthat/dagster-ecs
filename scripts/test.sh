#!/bin/bash
set -e

# Script to run type checking, linting, and tests
# Usage: ./scripts/test.sh

echo "Running type checking..."
ty check

echo "Running linting..."
ruff check . --fix
ruff format .

echo "Running tests..."
pytest

echo "✅ All tests passed!"