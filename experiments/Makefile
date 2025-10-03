# Makefile for Aider Environment Management

BENCHMARK := ../benchmarks/aider-genius
ENV_NAME := aider
PYTHON_VERSION := 3.12

# Default target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  create_env  - Create conda environment and install dependencies"
	@echo "  purge_env   - Remove the conda environment"
	@echo "  check_env   - Check if conda environment exists"
	@echo "  install_req - Install requirements in existing environment"
	@echo "  help        - Show this help message"

# Check if conda environment exists
.PHONY: check_env
check_env:
	@echo "Checking for conda environment: $(ENV_NAME)"
	@if conda env list | grep -q "^$(ENV_NAME) "; then \
		echo "Conda environment '$(ENV_NAME)' exists"; \
	else \
		echo "Conda environment '$(ENV_NAME)' not found"; \
		exit 1; \
	fi

# Create conda environment and install dependencies
.PHONY: create_env
create_env:
	@echo "Checking for conda environment: $(ENV_NAME)"
	@if conda env list | grep -q "^$(ENV_NAME) "; then \
		echo "Conda environment '$(ENV_NAME)' already exists"; \
	else \
		echo "Creating conda environment: $(ENV_NAME)"; \
		conda create -n $(ENV_NAME) python=$(PYTHON_VERSION) -y; \
		if [ $$? -eq 0 ]; then \
			echo "Successfully created conda environment: $(ENV_NAME)"; \
			if [ -f "$(BENCHMARK)/requirements.txt" ]; then \
				echo "Installing requirements from $(BENCHMARK)/requirements.txt"; \
				conda run -n $(ENV_NAME) pip install -r "$(BENCHMARK)/requirements.txt"; \
				if [ $$? -eq 0 ]; then \
					echo "Successfully installed requirements"; \
				else \
					echo "Failed to install requirements"; \
					exit 1; \
				fi; \
			else \
				echo "Warning: requirements.txt not found at $(BENCHMARK)/requirements.txt"; \
			fi; \
		else \
			echo "Failed to create conda environment: $(ENV_NAME)"; \
			exit 1; \
		fi; \
	fi
	@echo "Environment setup complete. You can activate it with: conda activate $(ENV_NAME)"

# Remove conda environment
.PHONY: purge_env
purge_env:
	@echo "Removing conda environment: $(ENV_NAME)"
	@if conda env list | grep -q "^$(ENV_NAME) "; then \
		conda env remove -n $(ENV_NAME) -y; \
		if [ $$? -eq 0 ]; then \
			echo "Successfully removed conda environment: $(ENV_NAME)"; \
		else \
			echo "Failed to remove conda environment: $(ENV_NAME)"; \
			exit 1; \
		fi; \
	else \
		echo "Conda environment '$(ENV_NAME)' does not exist"; \
	fi

# Install requirements in existing environment
.PHONY: install_req
install_req: check_env
	@echo "Installing requirements from $(BENCHMARK)/requirements.txt"
	@if [ -f "$(BENCHMARK)/requirements.txt" ]; then \
		conda run -n $(ENV_NAME) pip install -r "$(BENCHMARK)/requirements.txt"; \
		if [ $$? -eq 0 ]; then \
			echo "Successfully installed requirements"; \
		else \
			echo "Failed to install requirements"; \
			exit 1; \
		fi; \
	else \
		echo "Error: requirements.txt not found at $(BENCHMARK)/requirements.txt"; \
		exit 1; \
	fi

	conda run -n $(ENV_NAME) pip install datasets evaluate transformers

# Activate conda environment
.PHONY: activate_env
activate_env: check_env
	@echo "To activate the conda environment, run:"
	@echo "  conda activate $(ENV_NAME)"


# Run data_import.py script in the conda environment
.PHONY: data_import
data_import: data_import
	@echo "Running data_import.py in conda environment: $(ENV_NAME)"
	conda run -n $(ENV_NAME) python ./data_import.py