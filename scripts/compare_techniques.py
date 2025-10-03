#!/usr/bin/env python3
"""
Compare different prompt compilation techniques
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import List, Dict

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class TechniqueComparator:
    """Compare different prompt compilation techniques"""
    
    def __init__(self, results_dir="benchmarks/results"):
        self.results_dir = Path(results_dir)
        
    def load_latest_results(self) -> List[Dict]:
        """Load the most recent benchmark results"""
        if not self.results_dir.exists():
            logger.error(f"Results directory {self.results_dir} does not exist")
            return []
        
        # Find the most recent results file
        result_files = sorted(self.results_dir.glob("results_*.json"), reverse=True)
        
        if not result_files:
            logger.error("No result files found")
            return []
        
        latest_file = result_files[0]
        logger.info(f"Loading results from {latest_file}")
        
        with open(latest_file, 'r') as f:
            return json.load(f)
    
    def compare_techniques(self, results: List[Dict]):
        """Compare techniques and generate comparison report"""
        if not results:
            print("No results to compare")
            return
        
        # Group results by technique
        by_technique = {}
        for result in results:
            tech = result["technique"]
            if tech not in by_technique:
                by_technique[tech] = []
            by_technique[tech].append(result)
        
        print("\n" + "="*80)
        print("PROMPT COMPILATION TECHNIQUE COMPARISON")
        print("="*80)
        
        # Calculate metrics for each technique
        comparison_data = []
        
        for technique, tech_results in by_technique.items():
            num_runs = len(tech_results)
            
            metrics = {
                "technique": technique,
                "num_runs": num_runs,
                "avg_accuracy": sum(r["metrics"]["accuracy"] for r in tech_results) / num_runs,
                "avg_latency": sum(r["metrics"]["latency_ms"] for r in tech_results) / num_runs,
                "avg_tokens": sum(r["metrics"]["token_count"] for r in tech_results) / num_runs,
                "total_cost": sum(r["metrics"]["cost_usd"] for r in tech_results),
            }
            
            comparison_data.append(metrics)
        
        # Sort by accuracy (descending)
        comparison_data.sort(key=lambda x: x["avg_accuracy"], reverse=True)
        
        # Print comparison table
        print("\n{:<20} {:>10} {:>15} {:>15} {:>12} {:>12}".format(
            "Technique", "Runs", "Avg Accuracy", "Avg Latency", "Avg Tokens", "Total Cost"
        ))
        print("-" * 80)
        
        for data in comparison_data:
            print("{:<20} {:>10} {:>14.2%} {:>12.2f}ms {:>12.0f} ${:>10.4f}".format(
                data["technique"],
                data["num_runs"],
                data["avg_accuracy"],
                data["avg_latency"],
                data["avg_tokens"],
                data["total_cost"]
            ))
        
        print("\n" + "="*80)
        
        # Identify best technique for each metric
        print("\nBest Techniques by Metric:")
        print("-" * 40)
        
        best_accuracy = max(comparison_data, key=lambda x: x["avg_accuracy"])
        best_latency = min(comparison_data, key=lambda x: x["avg_latency"])
        best_tokens = min(comparison_data, key=lambda x: x["avg_tokens"])
        best_cost = min(comparison_data, key=lambda x: x["total_cost"])
        
        print(f"  Accuracy:  {best_accuracy['technique']} ({best_accuracy['avg_accuracy']:.2%})")
        print(f"  Latency:   {best_latency['technique']} ({best_latency['avg_latency']:.2f}ms)")
        print(f"  Tokens:    {best_tokens['technique']} ({best_tokens['avg_tokens']:.0f})")
        print(f"  Cost:      {best_cost['technique']} (${best_cost['total_cost']:.4f})")
        
        print("\n" + "="*80)
        
        # Save comparison report
        self.save_comparison(comparison_data)
    
    def save_comparison(self, comparison_data):
        """Save comparison data to file"""
        output_file = self.results_dir / "latest_comparison.json"
        
        with open(output_file, 'w') as f:
            json.dump(comparison_data, f, indent=2)
        
        logger.info(f"Comparison saved to {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Compare prompt compilation techniques"
    )
    parser.add_argument(
        "--results-dir",
        type=str,
        default="benchmarks/results",
        help="Directory containing benchmark results"
    )
    
    args = parser.parse_args()
    
    comparator = TechniqueComparator(results_dir=args.results_dir)
    results = comparator.load_latest_results()
    
    if results:
        comparator.compare_techniques(results)
        return 0
    else:
        logger.error("No results available for comparison")
        return 1


if __name__ == "__main__":
    sys.exit(main())
