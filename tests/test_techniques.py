"""
Tests for prompt compilation techniques
"""

import pytest
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from promptcompeval.techniques import (
    OriginalTechnique,
    ByLLMTechnique,
    OptimizedTechnique,
    CompressedTechnique
)


class TestOriginalTechnique:
    """Test the original technique"""
    
    def test_compile_returns_unchanged(self):
        """Test that original technique returns prompt unchanged"""
        technique = OriginalTechnique()
        prompt = "This is a test prompt"
        result = technique.compile(prompt)
        assert result == prompt
        
    def test_name(self):
        """Test technique name"""
        technique = OriginalTechnique()
        assert technique.name == "original"


class TestByLLMTechnique:
    """Test the byLLM technique"""
    
    def test_initialization(self):
        """Test initialization with config"""
        config = {"model": "gpt-4"}
        technique = ByLLMTechnique(config)
        assert technique.model == "gpt-4"
        
    def test_default_model(self):
        """Test default model"""
        technique = ByLLMTechnique()
        assert technique.model == "gpt-4"
        
    def test_name(self):
        """Test technique name"""
        technique = ByLLMTechnique()
        assert technique.name == "byLLM"


class TestOptimizedTechnique:
    """Test the optimized technique"""
    
    def test_name(self):
        """Test technique name"""
        technique = OptimizedTechnique()
        assert technique.name == "optimized"


class TestCompressedTechnique:
    """Test the compressed technique"""
    
    def test_compression_ratio(self):
        """Test compression ratio configuration"""
        config = {"compression_ratio": 0.5}
        technique = CompressedTechnique(config)
        assert technique.compression_ratio == 0.5
        
    def test_default_compression_ratio(self):
        """Test default compression ratio"""
        technique = CompressedTechnique()
        assert technique.compression_ratio == 0.7
        
    def test_name(self):
        """Test technique name"""
        technique = CompressedTechnique()
        assert technique.name == "compressed"
