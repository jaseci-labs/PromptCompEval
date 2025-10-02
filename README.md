# PromptCompEval

Evaluation Methodology, Benchmarks and Datasets for Prompt Compilation Frameworks for AI-Integration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)

> **Quick Start**: See [QUICKSTART.md](QUICKSTART.md) for a fast introduction to running benchmarks.

## Overview

PromptCompEval is an evaluation framework for comparing different prompt compilation techniques such as byLLM, optimized prompts, and compressed prompts. The framework provides tools to benchmark these techniques across various metrics including accuracy, latency, token count, and cost.

## Quick Start

### Setup

```bash
# Option 1: Using the Makefile (recommended)
make setup

# Option 2: Using the setup script
./scripts/setup.sh

# Option 3: Manual setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Running Benchmarks

```bash
# Activate the virtual environment (if not already active)
source venv/bin/activate

# Run all benchmarks
make benchmark

# Run quick benchmarks (sample data only)
make benchmark-fast

# Run full benchmark suite
make benchmark-full

# Compare different techniques
make benchmark-compare
```

## Project Structure

```
PromptCompEval/
├── src/
│   └── promptcompeval/     # Core evaluation framework
│       ├── __init__.py
│       ├── evaluator.py    # Main evaluator class
│       └── techniques.py   # Prompt compilation techniques
├── benchmarks/
│   ├── configs/            # Benchmark configurations
│   │   └── default.yaml
│   ├── data/               # Benchmark datasets
│   │   └── sample_dataset.json
│   ├── results/            # Benchmark results (generated)
│   └── logs/               # Benchmark logs (generated)
├── scripts/
│   ├── run_benchmarks.py   # Main benchmark runner
│   ├── compare_techniques.py # Technique comparison tool
│   └── setup.sh            # Setup script
├── tests/                  # Unit tests
│   ├── __init__.py
│   └── test_techniques.py
├── Makefile                # Build automation
├── requirements.txt        # Python dependencies
└── README.md
```

## Available Make Commands

Run `make help` to see all available commands:

### Setup Commands
- `make setup` - Complete setup (create venv and install dependencies)
- `make install` - Install production dependencies
- `make install-dev` - Install development dependencies

### Testing Commands
- `make test` - Run all tests
- `make test-verbose` - Run tests with verbose output
- `make coverage` - Run tests with coverage report

### Benchmarking Commands
- `make benchmark` - Run all benchmarks
- `make benchmark-fast` - Run quick benchmarks only
- `make benchmark-full` - Run full benchmark suite
- `make benchmark-compare` - Compare different prompt compilation techniques

### Code Quality Commands
- `make lint` - Run linting checks
- `make format` - Auto-format code
- `make type-check` - Run type checking

### Utility Commands
- `make clean` - Remove build artifacts and cache files
- `make clean-results` - Remove benchmark results
- `make results` - Display latest benchmark results

## Running Benchmarks Directly

You can also run benchmarks directly using the Python scripts:

```bash
# Run standard benchmarks
python scripts/run_benchmarks.py

# Run quick benchmarks
python scripts/run_benchmarks.py --quick

# Run full benchmark suite
python scripts/run_benchmarks.py --full

# Specify custom config
python scripts/run_benchmarks.py --config benchmarks/configs/custom.yaml

# Compare techniques
python scripts/compare_techniques.py
```

## Prompt Compilation Techniques

The framework currently supports the following techniques:

1. **Original** - Baseline without any compilation
2. **byLLM** - Prompts compiled/optimized by an LLM
3. **Optimized** - Hand-optimized prompts
4. **Compressed** - Token-compressed prompts

## Configuration

Edit `benchmarks/configs/default.yaml` to configure:
- Techniques to evaluate
- Datasets to use
- Evaluation metrics
- Model settings
- Output options

## Adding Custom Datasets

Add your datasets to `benchmarks/data/` in JSON format:

```json
[
  {
    "id": 1,
    "prompt": "Your prompt here",
    "expected_output": "Expected result",
    "category": "task_category"
  }
]
```

## Development

### Running Tests

```bash
# Run all tests
make test

# Run with coverage
make coverage
```

### Code Quality

```bash
# Format code
make format

# Run linting
make lint

# Type checking
make type-check
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this framework in your research, please cite:

```bibtex
@software{promptcompeval,
  title = {PromptCompEval: Evaluation Framework for Prompt Compilation Techniques},
  author = {Jaseci Labs},
  year = {2024},
  url = {https://github.com/jaseci-labs/PromptCompEval}
}
```