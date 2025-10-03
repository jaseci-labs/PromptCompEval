from datasets import load_dataset
import json

# Login using e.g. `huggingface-cli login` to access this dataset
ds = load_dataset("princeton-nlp/SWE-bench_Lite")
test = ds['test']

# Get 300 samples from the test split
test_samples = test.select(range(min(100, len(test))))

# Convert to list of dictionaries for JSON serialization
test_data = []
for i in range(len(test_samples)):
    test_data.append(test_samples[i])

# Save to JSON file
with open("test_data.json", "w") as f:
    json.dump(test_data, f, indent=2, default=str)

print(f"Saved {len(test_data)} samples to test_data.json")
print(f"Total samples available in test split: {len(test)}")
print(f"Sample keys: {list(test_data[0].keys()) if test_data else 'No data'}")