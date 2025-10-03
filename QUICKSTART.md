# PromptCompEval Quick Start Guide

## Installation

```bash
# Clone the repository
git clone https://github.com/jaseci-labs/PromptCompEval.git
cd PromptCompEval

# Setup environment (creates venv and installs dependencies)
make setup

# Activate the virtual environment
source venv/bin/activate
```

## Running Your First Benchmark

```bash
# Run a quick benchmark
make benchmark-fast

# View the results
make results
```

## Common Commands

### Benchmarking
```bash
make benchmark              # Run standard benchmarks
make benchmark-fast         # Quick test with sample data
make benchmark-full         # Full benchmark suite
make benchmark-compare      # Compare techniques
```

### Testing
```bash
make test                   # Run all tests
make coverage              # Run tests with coverage
```

### Development
```bash
make install-dev           # Install dev dependencies
make format                # Auto-format code
make lint                  # Run linting
make clean                 # Clean build artifacts
```

## Project Structure Overview

```
PromptCompEval/
├── Makefile                # All automation commands
├── scripts/
│   ├── run_benchmarks.py   # Main benchmark runner
│   └── compare_techniques.py # Comparison tool
├── benchmarks/
│   ├── configs/            # Benchmark configurations
│   ├── data/               # Datasets
│   └── results/            # Generated results
├── src/promptcompeval/     # Core framework
└── tests/                  # Unit tests
```

## Example Usage

```python
from promptcompeval import OriginalTechnique, ByLLMTechnique

# Create techniques
original = OriginalTechnique()
by_llm = ByLLMTechnique({"model": "gpt-4"})

# Compile a prompt
prompt = "Your prompt here"
compiled = by_llm.compile(prompt)
```

## Configuration

Edit `benchmarks/configs/default.yaml` to customize:
- Which techniques to evaluate
- Which datasets to use
- Evaluation metrics
- Model settings

## Getting Help

```bash
make help                  # Show all available commands
python scripts/run_benchmarks.py --help  # Script help
```

## Next Steps

1. Check out the [full README](README.md) for detailed documentation
2. Read [CONTRIBUTING.md](CONTRIBUTING.md) if you want to contribute
3. Look at examples in the `examples/` directory
4. Customize configurations in `benchmarks/configs/`
5. Add your own datasets to `benchmarks/data/`

## Troubleshooting

**Issue**: Python not found  
**Solution**: Install Python 3.8 or higher

**Issue**: Dependencies fail to install  
**Solution**: Try upgrading pip: `pip install --upgrade pip`

**Issue**: Tests failing  
**Solution**: Ensure you're in the virtual environment: `source venv/bin/activate`

For more help, open an issue on GitHub.
