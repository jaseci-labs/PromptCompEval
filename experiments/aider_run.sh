#!/bin/bash

BENCHMARK="../benchmarks/aider-genius"
ENV_NAME="aider"

# Function to check if conda environment exists
check_conda_env() {
    conda env list | grep -q "^${ENV_NAME} "
}

# Function to create conda environment
create_conda_env() {
    echo "Creating conda environment: ${ENV_NAME}"
    conda create -n ${ENV_NAME} python=3.12 -y
    
    if [ $? -eq 0 ]; then
        echo "Successfully created conda environment: ${ENV_NAME}"
        return 0
    else
        echo "Failed to create conda environment: ${ENV_NAME}"
        return 1
    fi
}

# Function to install requirements
install_requirements() {
    echo "Installing requirements from ${BENCHMARK}/requirements.txt"
    conda run -n ${ENV_NAME} pip install -r "${BENCHMARK}/requirements.txt"
    
    if [ $? -eq 0 ]; then
        echo "Successfully installed requirements"
        return 0
    else
        echo "Failed to install requirements"
        return 1
    fi
}

# Main logic
echo "Checking for conda environment: ${ENV_NAME}"

if check_conda_env; then
    echo "Conda environment '${ENV_NAME}' already exists"
else
    echo "Conda environment '${ENV_NAME}' not found"
    
    # Create the environment
    if create_conda_env; then
        # Install requirements if environment was created successfully
        if [ -f "${BENCHMARK}/requirements.txt" ]; then
            install_requirements
        else
            echo "Warning: requirements.txt not found at ${BENCHMARK}/requirements.txt"
        fi
    else
        echo "Exiting due to environment creation failure"
        exit 1
    fi
fi

echo "Environment setup complete. You can activate it with: conda activate ${ENV_NAME}"

