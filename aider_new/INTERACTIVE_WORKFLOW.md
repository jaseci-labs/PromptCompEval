# Interactive Aider Workflow for SWE-Bench

## Overview

This workflow allows you to run aider-genius interactively for each SWE-Bench test instance. For each entry:
1. The repo is cloned and checked out to the specified commit
2. A new Terminal.app window opens with aider running interactively
3. You can observe aider's work, inspect changes, and intervene if needed
4. When you close the Terminal window, the pipeline continues to the next instance

## Requirements

- **macOS** (uses Terminal.app and AppleScript)
- **Python 3** (for pty_run.py and placeholder replacement)
- **Conda environment** named `aider` with aider installed (or aider available on PATH)
- **test_data.json** with SWE-Bench instances

## Quick Start

### Run All Instances Interactively

```bash
cd /Users/jayanaka-98/Repos/PromptCompEval/aider_new
make run
```

This will:
- Process each instance in `test_data.json` sequentially
- Open a new Terminal window for each instance
- Wait for you to close each Terminal window before continuing

### Run a Single Instance

```bash
make run_one INSTANCE_ID=astropy__astropy-12907
```

## How It Works

### Per-Instance Flow

1. **Orchestrator** (`run_exp.py`):
   - Reads `test_data.json`
   - For each instance: clones repo, checks out commit, writes problem statement
   - Calls `run_test.sh` for that instance

2. **run_test.sh**:
   - Creates a wrapper script (`<instance_id>.launch.sh`) in `outputs/<instance_id>/`
   - The wrapper:
     - Changes to the cloned repo directory
     - Uses `pty_run.py` to run aider with a proper PTY (prevents "Input is not a terminal" warnings)
     - Passes the task/problem statement to aider
     - Drops to an interactive shell after aider exits
   - Uses `osascript` to open Terminal.app and run the wrapper
   - Polls until the wrapper process exits (i.e., you close the Terminal window)
   - Captures git diffs and commit info

3. **User Action**:
   - Observe aider working in the Terminal window
   - Inspect changes, run tests, etc.
   - **Close the Terminal window** (or exit the shell) when ready to continue

4. **Orchestrator continues**:
   - Captures the diff from the repo
   - Writes a prediction entry to `outputs/predictions.jsonl`
   - Moves to the next instance

## File Structure

```
aider_new/
├── run_exp.py              # Main orchestrator
├── run_test.sh             # Per-instance runner (launches Terminal)
├── pty_run.py              # PTY helper (gives aider a real terminal)
├── test_data.json          # SWE-Bench instances
├── Makefile                # Convenience targets
└── outputs/
    ├── orchestrator.log    # High-level pipeline log
    ├── predictions.jsonl   # Final predictions for evaluation
    ├── repos/              # Cloned repositories
    │   └── astropy_astropy/
    └── <instance_id>/      # Per-instance outputs
        ├── problem.txt     # Task description
        ├── <instance_id>.launch.sh       # Wrapper script
        ├── <instance_id>.run.log         # run_test.sh log
        ├── <instance_id>.diff            # Git diff (if any)
        └── <instance_id>.lastcommit.txt  # Last commit info
```

## Key Features

### PTY Runner Integration

The wrapper uses `pty_run.py` to run aider inside a pseudo-terminal. This ensures:
- Aider doesn't complain about "Input is not a terminal (fd=0)"
- The Genius agent doesn't prematurely cancel the task
- Interactive features work properly

`pty_run.py`:
- Reads the task from the problem file
- Spawns aider in a PTY
- Waits for startup markers (e.g., "Genius Agent", "Aider v")
- Sends the task followed by Enter
- Waits for completion markers or timeout
- Optionally sends `/exit` to terminate gracefully
- Streams all output for logging

### Terminal Window Management

- **Title**: Each Terminal window is titled `AIDER:<instance_id>` for easy identification
- **Working Directory**: The wrapper changes to the cloned repo before running aider
- **Interactive Shell**: After aider exits, the wrapper launches an interactive shell so you can inspect the repo before closing
- **Polling**: `run_test.sh` polls for the wrapper process to exit (detects when you close the Terminal)

### Fallback Behavior

- **Non-macOS**: If not on macOS or `osascript` is unavailable, falls back to non-interactive mode (expect or `--genius-task`)
- **No PTY Runner**: If `pty_run.py` is not found, the wrapper falls back to `--genius-task` (non-PTY)

## Troubleshooting

### Terminal Window Doesn't Appear

1. **Check macOS Automation Permissions**:
   - System Settings → Privacy & Security → Automation
   - Ensure the app calling `osascript` (Terminal, bash, Python) can control Terminal.app

2. **Run from Terminal.app** (not from VS Code or SSH):
   ```bash
   # Open Terminal.app and run from there
   cd /Users/jayanaka-98/Repos/PromptCompEval/aider_new
   make run_one INSTANCE_ID=astropy__astropy-12907
   ```

3. **Check if osascript works manually**:
   ```bash
   osascript -e 'tell application "Terminal" to activate'
   ```

### Aider Exits with "Task input cancelled by user"

This happens when aider doesn't get a proper PTY. Verify:

1. **pty_run.py exists and is accessible**:
   ```bash
   ls -l /Users/jayanaka-98/Repos/PromptCompEval/aider_new/pty_run.py
   ```

2. **Wrapper uses absolute PTY path**:
   ```bash
   grep PTY_RUN outputs/<instance_id>/<instance_id>.launch.sh
   # Should show: PTY_RUN='/absolute/path/to/pty_run.py'
   ```

3. **Regenerate the wrapper** (if it has an old relative path):
   ```bash
   make run_one INSTANCE_ID=<instance_id>
   ```

4. **Check wrapper output for "Using PTY runner"**:
   ```bash
   bash outputs/<instance_id>/<instance_id>.launch.sh
   # Look for: "Using PTY runner: /path/to/pty_run.py"
   ```

### Aider Command Issues

Check the resolved aider command in the run log:
```bash
grep "AIDER_CMD resolved" outputs/<instance_id>/<instance_id>.run.log
```

Expected:
- `conda run -n aider python -m aider.main` (if conda env exists)
- `python -m aider.main` (if aider is importable)
- `aider` or `jac-coder` (CLI fallbacks)

### No Git Repo Warning

If aider reports "Git repo: none", the wrapper didn't `cd` into the cloned repo. Check:
```bash
grep "Changed directory" outputs/<instance_id>/<instance_id>.run.log
```

## Advanced Usage

### Run Specific Instances

Edit `test_data.json` to include only the instances you want, or use:
```bash
python3 run_exp.py --instance astropy__astropy-12907
```

### Modify Aider Flags

Edit `run_test.sh` and change the aider invocation flags:
```bash
# Current flags:
--genius --yes --auto-commits --no-suggest-shell-commands --no-gitignore .

# Example modifications:
# - Remove --yes to make aider ask for confirmation
# - Add --subtree-only to limit repo-map for large repos
# - Add --model <model> to use a different model
```

### Clean Up Old Outputs

```bash
make clean_outputs
```

## Environment Setup

### Create Conda Environment (if needed)

```bash
make create_env
```

This creates a conda environment named `aider` with Python 3.12 and installs requirements from `../benchmarks/aider-genius/requirements.txt`.

### Verify Environment

```bash
conda activate aider
python -c "import aider; print(aider.__version__)"
```

## Tips

- **One Instance at a Time**: The pipeline is sequential — only one Terminal window opens at a time
- **Close Window to Continue**: The pipeline waits for you to close each Terminal window before moving to the next instance
- **Logs are Preserved**: All logs, diffs, and commits are saved under `outputs/<instance_id>/`
- **Resume After Interrupt**: If you interrupt the pipeline, you can re-run `make run` and it will process all instances again (or manually skip completed ones)

## Next Steps

After running the pipeline:

1. **Review predictions**:
   ```bash
   cat outputs/predictions.jsonl
   ```

2. **Evaluate with SWE-Bench tools** (if available):
   ```bash
   # Example evaluation command (adjust as needed)
   python -m swebench.evaluate --predictions outputs/predictions.jsonl --dataset <dataset>
   ```

3. **Inspect individual diffs**:
   ```bash
   cat outputs/<instance_id>/<instance_id>.diff
   ```

## Support

If you encounter issues:

1. Check `outputs/orchestrator.log` for high-level pipeline errors
2. Check `outputs/<instance_id>/<instance_id>.run.log` for per-instance errors
3. Run a single instance manually to debug:
   ```bash
   bash run_test.sh <repo_dir> <commit> <instance_id> outputs/<instance_id>
   ```
