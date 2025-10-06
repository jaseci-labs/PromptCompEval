# Docker Automation for SWE-bench

This directory contains Docker automation scripts for running SWE-bench entries with aider installed.

## Directory Structure

```
.
├── test_data.json          # Dataset entries to process
├── run_entry.py            # Main script to run entries
├── docker/
│   ├── Dockerfile          # Docker image definition
│   └── entrypoint.sh       # Container entrypoint script
└── logs/                   # Output logs from each run
    ├── 0/                  # Logs from first entry
    ├── 1/                  # Logs from second entry
    └── ...
```

## Files

### `docker/Dockerfile`
- Based on Python 3.12-slim
- Installs git, curl, build-essential
- Installs aider from the local benchmarks/aider-genius directory
- Sets up workspace and entrypoint

### `docker/entrypoint.sh`
- Clones the specified repository & checks out target commit
- Creates an isolated Python virtualenv per repo+commit at `/workspace/envs/<repo>_<commit>` so aider's global deps never conflict
- Heuristically installs only necessary dependencies:
  - Always installs `requirements.txt` first (if present)
  - Installs test tooling (`pytest`, etc.)
  - Installs heavy scientific stack (numpy/scipy/matplotlib/astropy-related) only if detected in project metadata or forced
- Optionally installs repo in editable mode (can be skipped)
- Runs baseline tests inside the repo virtualenv, runs aider outside that env, then re-runs tests inside env
- Captures full logs & diffs under `/workspace/logs/`

#### Heuristic Scientific Dependency Detection
The script scans `requirements.txt`, `pyproject.toml`, and `setup.cfg` for: `numpy|scipy|astropy|cython|matplotlib`.
If found (or `AIDER_FORCE_SCI=1` set) it installs compatible wheel versions for Python 3.12 (e.g. `numpy>=1.26`). This avoids slow / failing source builds with legacy pins.

#### Environment Variables (Optional)
| Variable | Effect |
|----------|--------|
| `AIDER_FORCE_SCI=1` | Force install scientific stack even if not detected. |
| `AIDER_SKIP_EDITABLE=1` | Skip editable `pip install -e .` (useful if repo installation causes resolver issues). |

Example forcing scientific stack:
```bash
docker run --rm -e AIDER_FORCE_SCI=1 -v $(pwd)/logs/manual:/workspace/logs swebench-env <repo> <commit> "<test_cmd>" "<problem>"
```

Example skipping editable install:
```bash
docker run --rm -e AIDER_SKIP_EDITABLE=1 -v $(pwd)/logs/manual:/workspace/logs swebench-env <repo> <commit> "<test_cmd>" "<problem>"
```

### `run_entry.py`
- Main automation script
- Builds Docker image if needed
- Processes entries from `test_data.json`
- Creates separate log directories for each entry
- Mounts logs directory to container

### `test_data.json`
- Contains entries with:
  - `repo`: GitHub repository URL
  - `commit_hash`: Specific commit to checkout
  - `test_cmd`: Test command to run

## Usage

### Build Docker image
```bash
make build_docker
# or
python run_entry.py --build
```

### Run all entries
```bash
make run_docker_entry
# or  
python run_entry.py
```

### Clean up Docker image
```bash
make clean_docker
```

### Run single entry manually
```bash
docker run --rm -v $(pwd)/logs/manual:/workspace/logs swebench-env \
    https://github.com/astropy/astropy.git \
    d16bfe05a744909de4b27f5875fe0d4ed41ce607 \
    "python -m pytest astropy/modeling/tests/test_separable.py::test_separable -xvs"
```

## Output

Each entry creates a log directory under `logs/` containing:
- `test_output.log`: Complete test output with repository info and test results
- Any additional files created during execution

## Integration with Aider

The Docker image includes aider installed from the local `benchmarks/aider-genius` directory. You can extend the entrypoint script to:
1. Apply patches using aider
2. Run tests before and after patches
3. Generate diffs and reports
4. Save results for analysis

## Example Dataset Entry

```json
{
  "repo": "https://github.com/astropy/astropy.git",
  "commit_hash": "d16bfe05a744909de4b27f5875fe0d4ed41ce607", 
  "test_cmd": "python -m pytest astropy/modeling/tests/test_separable.py::test_separable -xvs"
}
```