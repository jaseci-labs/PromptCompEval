import json
import os
import subprocess
import sys

with open('test_data.json', 'r') as f:
    data = json.load(f)

instance_ids = [item['instance_id'] for item in data]

for instance_id in instance_ids:
    print(f"Running experiment for instance_id: {instance_id}")
    result = subprocess.run(
        ["make", "run_one", f"INSTANCE_ID={instance_id}"],
        capture_output=True,
        text=True
    )
    print(result.stdout)
    if result.stderr:
        print(f"Error: {result.stderr}", file=sys.stderr)