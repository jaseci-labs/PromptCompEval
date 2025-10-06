#!/bin/bash

# Test script for Docker automation setup

echo "=== Testing Docker Automation Setup ==="

# Check if required files exist
echo "Checking required files..."
files=("test_data.json" "run_entry.py" "docker/Dockerfile" "docker/entrypoint.sh")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        exit 1
    fi
done

# Check if Docker is available
echo "Checking Docker availability..."
if command -v docker &> /dev/null; then
    echo "✓ Docker is available"
    docker --version
else
    echo "✗ Docker not found"
    exit 1
fi

# Check if logs directory exists
if [ -d "logs" ]; then
    echo "✓ logs directory exists"
else
    echo "✓ logs directory will be created"
fi

# Validate JSON format
echo "Validating test_data.json..."
if python -m json.tool test_data.json > /dev/null 2>&1; then
    echo "✓ test_data.json is valid JSON"
else
    echo "✗ test_data.json is invalid JSON"
    exit 1
fi

# Check entry count
entry_count=$(python -c "import json; print(len(json.load(open('test_data.json'))))")
echo "✓ Found $entry_count entries in dataset"

echo ""
echo "=== Setup appears to be ready! ==="
echo "Next steps:"
echo "1. Run 'make build_docker' to build the Docker image"
echo "2. Run 'make run_docker_entry' to process all entries"
echo "3. Check logs/ directory for results"