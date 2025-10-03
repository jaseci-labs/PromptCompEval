.PHONY: help install install-dev test benchmark clean lint format setup

# Default target
help:
	@echo "PromptCompEval - Makefile Commands"
	@echo "=================================="
	@echo ""
	@echo "Setup:"
	@echo "  make setup          - Complete setup (create venv and install dependencies)"
	@echo "  make install        - Install production dependencies"
	@echo "  make install-dev    - Install development dependencies"
	@echo ""
	@echo "Testing:"
	@echo "  make test           - Run all tests"
	@echo "  make test-verbose   - Run tests with verbose output"
	@echo "  make coverage       - Run tests with coverage report"
	@echo ""
	@echo "Benchmarking:"
	@echo "  make benchmark      - Run all benchmarks"
	@echo "  make benchmark-fast - Run quick benchmarks only"
	@echo "  make benchmark-full - Run full benchmark suite"
	@echo "  make benchmark-compare - Compare different prompt compilation techniques"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint           - Run linting checks"
	@echo "  make format         - Auto-format code"
	@echo "  make type-check     - Run type checking"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean          - Remove build artifacts and cache files"
	@echo "  make clean-results  - Remove benchmark results"
	@echo "  make results        - Display latest benchmark results"

# Setup and installation
setup:
	@echo "Setting up PromptCompEval environment..."
	python3 -m venv venv
	@echo "Activating virtual environment and installing dependencies..."
	. venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt
	@echo "Setup complete! Activate the environment with: source venv/bin/activate"

install:
	pip install -r requirements.txt

install-dev:
	pip install -r requirements.txt
	pip install black flake8 mypy pylint isort

# Testing
test:
	@echo "Running tests..."
	pytest tests/ -v

test-verbose:
	pytest tests/ -vv -s

coverage:
	@echo "Running tests with coverage..."
	pytest tests/ --cov=src --cov-report=html --cov-report=term

# Benchmarking
benchmark:
	@echo "Running benchmarks..."
	python scripts/run_benchmarks.py

benchmark-fast:
	@echo "Running quick benchmarks..."
	python scripts/run_benchmarks.py --quick

benchmark-full:
	@echo "Running full benchmark suite..."
	python scripts/run_benchmarks.py --full

benchmark-compare:
	@echo "Comparing prompt compilation techniques..."
	python scripts/compare_techniques.py

# Code quality
lint:
	@echo "Running linting checks..."
	flake8 src/ tests/ --max-line-length=100
	pylint src/

format:
	@echo "Formatting code..."
	black src/ tests/ scripts/
	isort src/ tests/ scripts/

type-check:
	@echo "Running type checks..."
	mypy src/

# Utilities
clean:
	@echo "Cleaning build artifacts..."
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "htmlcov" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name ".coverage" -delete
	rm -rf build/ dist/

clean-results:
	@echo "Cleaning benchmark results..."
	rm -rf benchmarks/results/*
	rm -rf benchmarks/logs/*

results:
	@echo "Latest benchmark results:"
	@if [ -d "benchmarks/results" ]; then \
		ls -lt benchmarks/results/ | head -10; \
	else \
		echo "No results found. Run 'make benchmark' first."; \
	fi
