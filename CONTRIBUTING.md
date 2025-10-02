# Contributing to PromptCompEval

Thank you for your interest in contributing to PromptCompEval! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up your development environment

```bash
git clone https://github.com/YOUR_USERNAME/PromptCompEval.git
cd PromptCompEval
make setup
source venv/bin/activate
```

## Development Workflow

### Setting Up Development Environment

```bash
# Install with development dependencies
make install-dev

# Or manually
pip install -r requirements.txt
pip install black flake8 mypy pylint isort pytest pytest-cov
```

### Making Changes

1. Create a new branch for your feature or bug fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the coding standards

3. Run tests to ensure your changes don't break anything:
   ```bash
   make test
   ```

4. Format your code:
   ```bash
   make format
   ```

5. Run linting:
   ```bash
   make lint
   ```

### Testing

- Write tests for new features or bug fixes
- Ensure all tests pass before submitting a PR
- Aim for good test coverage

```bash
# Run all tests
make test

# Run with coverage
make coverage
```

### Code Style

We follow these style guidelines:

- **Python**: PEP 8 style guide
- **Line length**: 100 characters
- **Formatter**: Black
- **Import sorting**: isort

Run `make format` to automatically format your code.

### Commit Messages

Write clear, concise commit messages:

- Use the imperative mood ("Add feature" not "Added feature")
- First line should be 50 characters or less
- Provide detailed description in the body if needed

Example:
```
Add byLLM technique implementation

- Implement LLM API integration
- Add configuration for different models
- Include error handling for API failures
```

## Adding New Features

### Adding a New Prompt Compilation Technique

1. Create a new class in `src/promptcompeval/techniques.py` that inherits from `BaseTechnique`
2. Implement the `compile()` method
3. Add tests in `tests/test_techniques.py`
4. Update documentation in README.md

Example:
```python
class MyNewTechnique(BaseTechnique):
    def __init__(self, config: Dict[str, Any] = None):
        super().__init__("my_new_technique", config)
    
    def compile(self, prompt: str) -> str:
        # Your implementation here
        return compiled_prompt
```

### Adding a New Metric

1. Add the metric to `src/promptcompeval/evaluator.py`
2. Update the configuration schema in `benchmarks/configs/default.yaml`
3. Add tests
4. Update documentation

### Adding a New Dataset

1. Add your dataset to `benchmarks/data/`
2. Follow the JSON format:
   ```json
   [
     {
       "id": 1,
       "prompt": "Your prompt",
       "expected_output": "Expected result",
       "category": "category_name"
     }
   ]
   ```
3. Update configuration in `benchmarks/configs/default.yaml`

## Submitting Changes

1. Push your changes to your fork
2. Create a pull request against the main repository
3. Describe your changes in the PR description
4. Link any related issues
5. Wait for review and address any feedback

## Pull Request Guidelines

- Keep PRs focused on a single feature or bug fix
- Include tests for new functionality
- Update documentation as needed
- Ensure all tests pass
- Follow the code style guidelines
- Respond to review comments promptly

## Reporting Issues

When reporting issues, please include:

- A clear description of the problem
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- System information (OS, Python version, etc.)
- Relevant logs or error messages

## Questions?

If you have questions, please:

- Check existing issues and discussions
- Open a new issue with the "question" label
- Reach out to the maintainers

## Code of Conduct

Be respectful and professional in all interactions. We're all here to make this project better!

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
