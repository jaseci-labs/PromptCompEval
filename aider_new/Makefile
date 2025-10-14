# Makefile for Aider run utilities (aider_new)

BENCHMARK := ../benchmarks/aider-genius
ENV_NAME := aider
PYTHON := python3
PYTHON_VERSION := 3.12

# Default target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  create_env       - Create conda environment and install dependencies"
	@echo "  purge_env        - Remove the conda environment"
	@echo "  check_env        - Check if conda environment exists"
	@echo "  install_req      - Install requirements in existing environment"
	@echo "  run              - Run the full experiment pipeline (run_exp.py)"
	@echo "  run_one          - Run a single instance via run_test.sh (set REPO_DIR, COMMIT, INSTANCE_ID)"
	@echo "  clean            - Remove generated outputs/logs"
	@echo "  data_import      - Run data_import.py in conda environment"
	@echo "  help             - Show this help message"

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
		echo "Warning: requirements.txt not found at $(BENCHMARK)/requirements.txt"; \
	fi

	# Additional tooling commonly used by scripts
	conda run -n $(ENV_NAME) pip install --no-input datasets evaluate transformers || true

# Activate conda environment
.PHONY: activate_env
activate_env: check_env
	@echo "To activate the conda environment, run:"
	@echo "  conda activate $(ENV_NAME)"


# Run data_import.py script in the conda environment
.PHONY: data_import
data_import:
	@echo "Running data_import.py in conda environment: $(ENV_NAME)"
	conda run -n $(ENV_NAME) $(PYTHON) ./data_import.py

.PHONY: run
run:
	@echo "Running full experiment pipeline (run_exp.py)..."
	$(PYTHON) run_exp.py

.PHONY: run_one
# Usage:
#  make run_one INSTANCE_ID=<id>                 # run the entry from test_data.json via run_exp.py
#  make run_one REPO_DIR=/path COMMIT=<sha> INSTANCE_ID=<id>  # run single repo directly via run_test.sh
run_one:
	@if [ -n "$(INSTANCE_ID)" ] && [ -z "$(REPO_DIR)" ]; then \
		$(PYTHON) run_exp.py --instance "$(INSTANCE_ID)"; \
	else \
		if [ -z "$(REPO_DIR)" ] || [ -z "$(COMMIT)" ] || [ -z "$(INSTANCE_ID)" ]; then \
			echo "Usage: make run_one INSTANCE_ID=<id>  OR  make run_one REPO_DIR=/path COMMIT=<sha> INSTANCE_ID=<id>"; exit 1; \
		fi; \
		OUT_DIR=outputs/$(INSTANCE_ID); mkdir -p $$OUT_DIR; \
		bash run_test.sh "$(REPO_DIR)" "$(COMMIT)" "$(INSTANCE_ID)" "$$OUT_DIR"; \
	fi

.PHONY: clean
clean:
	@echo "Removing outputs/ directory..."
	rm -rf outputs || true

# Docker automation targets
# (Docker automation targets removed — this Makefile focuses on local runs)