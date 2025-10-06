import json
import os
import subprocess
import sys

DATA_FILE = "test_data.json"

def run_entry(entry, idx):
    # Handle both formats: GitHub URL or just repo name
    repo = entry["repo"]
    if not repo.startswith("https://"):
        repo = f"https://github.com/{repo}.git"
    
    # Handle both field names: commit_hash or base_commit
    commit = entry.get("commit_hash") or entry.get("base_commit")
    if not commit:
        print(f"Error: No commit hash found in entry {idx}")
        return
    
    # Get the problem statement for aider
    problem_statement = entry.get("problem_statement", "")
    if not problem_statement:
        print(f"Warning: No problem statement found in entry {idx}")
    
    # Try to construct a test command from FAIL_TO_PASS tests if available
    test_cmd = entry.get("test_cmd")
    if not test_cmd:
        fail_to_pass = entry.get("FAIL_TO_PASS", "")
        if fail_to_pass and fail_to_pass != "[]":
            # Extract test names from the FAIL_TO_PASS field
            import json
            try:
                # Handle both string and list formats
                if isinstance(fail_to_pass, str):
                    if fail_to_pass.startswith('['):
                        tests = json.loads(fail_to_pass.replace("'", '"'))
                    else:
                        tests = [fail_to_pass]  # Single test as string
                else:
                    tests = fail_to_pass  # Already a list
                
                if tests:
                    # Handle Django test format: "test_str (model_enums.tests.ChoicesTests)" -> "model_enums.tests.ChoicesTests::test_str"
                    formatted_tests = []
                    for test in tests:
                        # Check if it's Django test format with parentheses
                        if ' (' in test and test.endswith(')'):
                            # Parse "test_str (model_enums.tests.ChoicesTests)" format
                            test_name = test.split(' (')[0]
                            test_class = test.split(' (')[1].rstrip(')')
                            formatted_test = f"{test_class}::{test_name}"
                            formatted_tests.append(formatted_test)
                        else:
                            # Normal pytest format, use as is
                            formatted_tests.append(test)
                    
                    # Use pytest command for Django tests
                    test_cmd = f"python -m pytest {' '.join(formatted_tests)} -rA -vv -o console_output_style=classic --tb=short"
                else:
                    test_cmd = "python -m pytest -rA -vv"
            except Exception as e:
                print(f"Warning: Failed to parse FAIL_TO_PASS field: {e}")
                test_cmd = "python -m pytest -rA -vv"
        else:
            test_cmd = "python -m pytest -rA -vv"

    logs_dir = f"logs/{idx}"
    os.makedirs(logs_dir, exist_ok=True)

    print(f"Running entry {idx}: {repo} at {commit}")
    print(f"Test command: {test_cmd}")
    print(f"Problem statement: {problem_statement[:100]}..." if len(problem_statement) > 100 else f"Problem statement: {problem_statement}")
    print(f"Logs will be saved to: {logs_dir}")

    # Pass through relevant env vars to avoid interactive auth inside container
    env_args = []
    if os.environ.get("OPENAI_API_KEY"):
        env_args += ["-e", "OPENAI_API_KEY"]  # docker will copy value from host env
    if os.environ.get("OPENROUTER_API_KEY"):
        env_args += ["-e", "OPENROUTER_API_KEY"]
    # Default model to gpt-4o unless overridden by host env AIDER_MODEL
    if os.environ.get("AIDER_MODEL"):
        env_args += ["-e", f"AIDER_MODEL={os.environ['AIDER_MODEL']}"]
    else:
        env_args += ["-e", "AIDER_MODEL=gpt-4o"]

    cmd = [
        "docker", "run", "--rm",
        "-v", f"{os.path.abspath(logs_dir)}:/workspace/logs",
    ] + env_args + [
        "swebench-env",   # built image name
        repo, commit, test_cmd, problem_statement
    ]

    print(f"Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=False)
    
    if result.returncode == 0:
        print(f"Entry {idx} completed successfully")
    else:
        print(f"Entry {idx} completed with errors (exit code: {result.returncode})")
    
    print("-" * 60)

def check_docker_access():
    """Quick check if Docker is accessible"""
    try:
        result = subprocess.run(
            ["docker", "--version"], 
            capture_output=True, 
            text=True,
            timeout=5
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False

def build_docker_image():
    """Build the Docker image with aider installed"""
    print("Building Docker image...")
    
    # Quick check if Docker is accessible
    if not check_docker_access():
        print("\nDocker is not accessible!")
        print("To fix Docker permissions:")
        print("1. Add your user to the docker group:")
        print("   sudo usermod -aG docker $USER")
        print("2. Log out and back in, or run:")
        print("   newgrp docker")
        print("3. Verify Docker works:")
        print("   docker --version")
        print("\nThen try again: make build_docker")
        sys.exit(1)
    
    # Copy the aider-genius directory to docker context
    cmd = [
        "cp", "-r", 
        "../benchmarks/aider-genius", 
        "docker/"
    ]
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print("Failed to copy aider-genius directory")
        sys.exit(1)
    
    # Build the image
    cmd = [
        "docker", "build", 
        "-t", "swebench-env", 
        "docker/"
    ]
    
    result = subprocess.run(cmd)
    
    # Clean up copied directory
    subprocess.run(["rm", "-rf", "docker/aider-genius"], check=False)
    
    if result.returncode != 0:
        print("\nFailed to build Docker image!")
        print("\nIf you see permission denied errors, you need to fix Docker permissions:")
        print("1. Add your user to the docker group:")
        print("   sudo usermod -aG docker $USER")
        print("2. Log out and back in, or run:")
        print("   newgrp docker")
        print("3. Verify Docker works without sudo:")
        print("   docker --version")
        print("\nThen try building again: make build_docker")
        sys.exit(1)
    
    print("Docker image built successfully")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--build":
        build_docker_image()
        sys.exit(0)
    
    # Check if Docker image exists
    result = subprocess.run(
        ["docker", "images", "-q", "swebench-env"], 
        capture_output=True, text=True
    )
    
    # If Docker command failed (permission denied), show helpful message
    if result.returncode != 0:
        print("\nDocker permission error detected!")
        print("To fix this, add your user to the docker group:")
        print("1. sudo usermod -aG docker $USER")
        print("2. Log out and back in, or run: newgrp docker")
        print("3. Then try again: make run_docker_entry")
        sys.exit(1)
    
    if not result.stdout.strip():
        print("Docker image 'swebench-env' not found. Building it first...")
        build_docker_image()
    
    # Load and run entries
    if not os.path.exists(DATA_FILE):
        print(f"Error: {DATA_FILE} not found")
        sys.exit(1)
    
    with open(DATA_FILE) as f:
        data = json.load(f)

    print(f"Found {len(data)} entries to process")
    
    for idx, entry in enumerate(data):
        print(f"\n=== Processing entry {idx + 1}/{len(data)} ===")
        run_entry(entry, idx)
    
    print(f"\nCompleted processing all {len(data)} entries")
    print("Check the logs/ directory for detailed output from each run")