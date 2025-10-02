#!/usr/bin/env python3
"""
Basic usage example for PromptCompEval
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from promptcompeval import (
    PromptEvaluator,
    OriginalTechnique,
    ByLLMTechnique,
    OptimizedTechnique,
    CompressedTechnique
)


def main():
    """Demonstrate basic usage of PromptCompEval"""
    
    print("="*60)
    print("PromptCompEval - Basic Usage Example")
    print("="*60)
    print()
    
    # Create an evaluator
    evaluator = PromptEvaluator()
    
    # Create different techniques
    techniques = [
        OriginalTechnique(),
        ByLLMTechnique({"model": "gpt-4"}),
        OptimizedTechnique(),
        CompressedTechnique({"compression_ratio": 0.7})
    ]
    
    # Sample prompt
    prompt = "Translate the following English text to French: 'Hello, how are you?'"
    
    print("Original Prompt:")
    print(f"  {prompt}")
    print()
    
    # Compile prompt with each technique
    print("Compiled Prompts:")
    for technique in techniques:
        compiled = technique.compile(prompt)
        print(f"  {technique.name:15} : {compiled}")
    
    print()
    print("="*60)
    print("Note: This is a demonstration with placeholder implementations.")
    print("Run 'make benchmark' to execute full benchmarks.")
    print("="*60)


if __name__ == "__main__":
    main()
