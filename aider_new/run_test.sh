#!/usr/bin/env bash
# run_test.sh: runs aider inside the conda environment named 'aider' for a cloned repo
# Usage: run_test.sh <repo_dir> <base_commit> <instance_id> <temp_output_dir>
set -euo pipefail

REPO_DIR="$1"
BASE_COMMIT="$2"
INSTANCE_ID="$3"
OUT_DIR="$4"

LOG_PREFIX="$OUT_DIR/${INSTANCE_ID}"
AIDER_ENV_NAME="aider"
AIDER_CMD=""

# Ensure out dir exists
mkdir -p "$OUT_DIR"

# Capture everything (stdout/stderr) to a run log for this instance
RUN_LOG="${OUT_DIR}/${INSTANCE_ID}.run.log"
mkdir -p "$(dirname "$RUN_LOG")"
# Redirect all output to the run log and also tee to stdout
exec > >(tee -a "$RUN_LOG") 2>&1

echo "=== run_test.sh start: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "REPO_DIR=$REPO_DIR BASE_COMMIT=$BASE_COMMIT INSTANCE_ID=$INSTANCE_ID OUT_DIR=$OUT_DIR"

pushd "$REPO_DIR" >/dev/null

# Clean up any uncommitted changes before checking out the base commit
echo "Cleaning up repository state before checkout..."
# Remove any untracked files and directories
git clean -fdx || true
# Reset any staged changes
git reset --hard HEAD || true
# Discard any uncommitted changes
git checkout -- . || true

# Checkout the provided commit
if git rev-parse --verify --quiet "$BASE_COMMIT" >/dev/null; then
    git checkout --force "$BASE_COMMIT" || true
else
    # try to fetch and checkout
    git fetch --all --quiet || true
    git checkout --force "$BASE_COMMIT" || true
fi

# Verify we're on the correct commit and clean
echo "Current commit: $(git rev-parse HEAD)"
echo "Target commit: $BASE_COMMIT"
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "$BASE_COMMIT")" ]; then
    echo "WARNING: Current HEAD does not match target commit!" >&2
fi

# Build the aider command. Prefer running the local installation via:
#   python -m aider.main --genius
# inside the `aider` conda env if available, else system python, else CLI fallbacks.
if command -v conda >/dev/null 2>&1 && conda env list | grep -q "^${AIDER_ENV_NAME} "; then
    CONDA_RUN=(conda run -n "$AIDER_ENV_NAME")
    # Check if aider is importable in that env
    if "${CONDA_RUN[@]}" python -c "import aider" >/dev/null 2>&1; then
        AIDER_CMD=("${CONDA_RUN[@]}" python -m aider.main)
    else
        echo "Conda env '${AIDER_ENV_NAME}' exists but 'aider' is not importable inside it; falling back to PATH" >&2
        if command -v python >/dev/null 2>&1 && python -c "import aider" >/dev/null 2>&1; then
            AIDER_CMD=(python -m aider.main)
        elif command -v jac-coder >/dev/null 2>&1; then
            AIDER_CMD=(jac-coder)
        elif command -v aider >/dev/null 2>&1; then
            AIDER_CMD=(aider)
        else
            echo "No aider found (conda env or system). Exiting." >&2
            exit 1
        fi
    fi
else
    # No conda env - try system python first
    if command -v python >/dev/null 2>&1 && python -c "import aider" >/dev/null 2>&1; then
        AIDER_CMD=(python -m aider.main)
    elif command -v jac-coder >/dev/null 2>&1; then
        AIDER_CMD=(jac-coder)
    elif command -v aider >/dev/null 2>&1; then
        AIDER_CMD=(aider)
    else
        echo "No aider available (system Python or CLI). Exiting." >&2
        exit 1
    fi
fi

# Prepare temporary input for aider: problem statement and exit
PROBLEM_FILE="${LOG_PREFIX}.problem.txt"
# Create a small placeholder problem file containing the current branch name
# (the real problem text should be written by the caller into $OUT_DIR/problem.txt)
git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
printf "%s\n" "$git_branch" > "$PROBLEM_FILE"

# Note: the above writing will just create a placeholder; the caller should pass problem via environment or file.
# Instead, we expect the caller to place a file named problem.txt in OUT_DIR (handled by run_exp.py)

if [ -f "$OUT_DIR/problem.txt" ]; then
    AIDER_INPUT_FILE="$OUT_DIR/problem.txt"
else
    AIDER_INPUT_FILE="$PROBLEM_FILE"
fi

# Run aider and capture logs
AIDER_LOG_FILE="${LOG_PREFIX}.aider.log"
DIFF_FILE="${LOG_PREFIX}.diff"

# Read problem content (preserve newlines)
TASK_CONTENT=""
if [ -f "$AIDER_INPUT_FILE" ]; then
    TASK_CONTENT=$(cat "$AIDER_INPUT_FILE") || TASK_CONTENT=""
fi

echo "--- TASK (truncated 1024 chars) ---" >> "$RUN_LOG"
echo "${TASK_CONTENT:0:1024}" >> "$RUN_LOG"
echo "--- END TASK ---" >> "$RUN_LOG"

# Log the resolved AIDER command for debugging
echo "AIDER_CMD resolved: ${AIDER_CMD[*]}" >> "$RUN_LOG" || true

# If on macOS, open a new Terminal.app window and run an interactive wrapper script
if [ "$(uname)" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
    WRAPPER_SCRIPT="${OUT_DIR}/${INSTANCE_ID}.launch.sh"

    # Build a safely-escaped command prefix from AIDER_CMD array
    CMD_PREFIX=""
    for _elem in "${AIDER_CMD[@]}"; do
        # shell-escape each element
        CMD_PREFIX+=$(printf "%q" "$_elem")
        CMD_PREFIX+=" "
    done
    # Trim trailing space
    CMD_PREFIX="${CMD_PREFIX% }"

    # Remove any existing wrapper (avoid stale scripts) and write the wrapper that will run inside the new Terminal window.
    rm -f "$WRAPPER_SCRIPT" || true
    # Use printf so we can safely insert parent-time values (INSTANCE_ID,
    # AIDER_INPUT_FILE, CMD_PREFIX) while leaving the runtime CMD variable
    # escaped (written as \${CMD}) so the parent shell doesn't expand it.
    cat > "$WRAPPER_SCRIPT" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
INSTANCE_ID='__INSTANCE_ID_PLACEHOLDER__'
TASK_FILE='__TASK_FILE_PLACEHOLDER__'
REPO_DIR='__REPO_DIR_PLACEHOLDER__'
MARKER_FILE='__MARKER_FILE_PLACEHOLDER__'
ERROR_LOG="${MARKER_FILE}.error.log"

# Log all errors
exec 2>> "$ERROR_LOG"
set -x  # Enable debugging

# Create marker file to indicate this session is active
touch "$MARKER_FILE" || { echo "Failed to create marker file" >> "$ERROR_LOG"; exit 1; }

# Ensure marker is removed on any exit
trap 'rm -f "$MARKER_FILE"; echo "Trap executed at $(date)" >> "$ERROR_LOG"' EXIT

printf '\033]0;%s\007' "AIDER:${INSTANCE_ID}"

# IMPORTANT: Change to repository directory FIRST before doing anything else
if [ -n "${REPO_DIR}" ] && [ -d "${REPO_DIR}" ]; then
    cd "${REPO_DIR}" || { echo "ERROR: Failed to cd to ${REPO_DIR}" >&2; exit 1; }
    echo "Changed directory to ${REPO_DIR}"
else
    echo "ERROR: Repository directory '${REPO_DIR}' not found or empty" >&2
    exit 1
fi

echo "===== AIDER interactive session: ${INSTANCE_ID} ====="
echo "Current directory: $(pwd)"
echo ""
echo "Task (first 1024 chars):"
head -c 1024 "${TASK_FILE}" || true
echo
echo "Launching aider (interactive). When done, close this window to allow the experiment to continue."
echo
CMD='__CMD_PLACEHOLDER__'
# Create a single-line version for clipboard
ONELINE_FILE="${TASK_FILE}.oneline"
# Convert ALL line endings (both \r\n and \n) to spaces
cat "${TASK_FILE}" | tr '\r\n' '  ' > "$ONELINE_FILE"

echo ""
echo "=========================================="
echo "TASK (full text - showing first 10 lines):"
echo "=========================================="
head -10 "${TASK_FILE}"
echo ""
echo "=========================================="
echo ""
echo "Single-line version for copy-paste:"
cat "$ONELINE_FILE"
echo ""
echo "=========================================="
echo ""
echo "Copying single-line version to clipboard..."
cat "$ONELINE_FILE" | pbcopy
echo "✓ Done! Paste at aider > prompt and press Enter"
echo ""
echo "=========================================="
echo ""

# Run aider interactively - user will paste the task at the prompt
echo "Starting aider in genius mode..."
echo ""

# Activate conda environment and run aider directly
set +e  # Don't exit on error
eval "$(conda shell.bash hook)"
conda activate aider

# Run aider from the current directory (which is the repo directory)
# Aider will automatically detect the git repo
python -m aider.main --genius
AIDER_EXIT_CODE=$?
set -e

echo ""
echo "DEBUG: Aider exited with code: $AIDER_EXIT_CODE"
echo ""
echo "=========================================="
echo "Aider process completed!"
echo "Exit code: $AIDER_EXIT_CODE"
echo "=========================================="
echo ""
echo "Terminal will close in 5 seconds to continue the pipeline..."
echo "Press Ctrl+C if you need more time to inspect the changes."
echo ""

# Give user a few seconds to see the exit status, then automatically exit
sleep 5

# The trap will automatically remove the marker file on exit
echo "Closing terminal and continuing pipeline..."
WRAPPER

    # Now replace placeholders with the actual safe values
    # Use sed to substitute; CMD_PREFIX may contain single quotes, so we'll
    # replace __CMD_PLACEHOLDER__ using a temporary file and printf
    # Safely replace placeholders using python to avoid complex shell quoting
    # Compute absolute path to pty_run.py relative to this script
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PTY_RUN_PATH="$SCRIPT_DIR/pty_run.py"
    MARKER_FILE="${OUT_DIR}/${INSTANCE_ID}.active"
    python3 - "$WRAPPER_SCRIPT" "${INSTANCE_ID}" "${AIDER_INPUT_FILE}" "${CMD_PREFIX}" "${REPO_DIR}" "$PTY_RUN_PATH" "$MARKER_FILE" <<'PY'
import sys
path = sys.argv[1]
inst = sys.argv[2]
taskf = sys.argv[3]
cmd = sys.argv[4]
repod = sys.argv[5]
ptyrun = sys.argv[6]
marker = sys.argv[7]
with open(path, 'r', encoding='utf-8') as f:
    s = f.read()
s = s.replace('__INSTANCE_ID_PLACEHOLDER__', inst)
s = s.replace('__TASK_FILE_PLACEHOLDER__', taskf)
s = s.replace('__CMD_PLACEHOLDER__', cmd)
s = s.replace('__REPO_DIR_PLACEHOLDER__', repod)
s = s.replace('__PTY_RUN_PLACEHOLDER__', ptyrun)
s = s.replace('__MARKER_FILE_PLACEHOLDER__', marker)
with open(path, 'w', encoding='utf-8') as f:
    f.write(s)
PY

    chmod +x "$WRAPPER_SCRIPT"
    echo "WROTE WRAPPER: $WRAPPER_SCRIPT (size=$(stat -f%z "$WRAPPER_SCRIPT" 2>/dev/null || stat -c%s "$WRAPPER_SCRIPT" 2>/dev/null || echo 'unknown'))" >> "$RUN_LOG" || true

    # Log osascript availability and wrapper path
    if command -v osascript >/dev/null 2>&1; then
        echo "osascript found, launching Terminal with wrapper: $WRAPPER_SCRIPT" >> "$RUN_LOG"
    else
        echo "osascript NOT found; cannot open Terminal.app" >> "$RUN_LOG"
    fi

    # Ask Terminal.app to open a new window and run the wrapper
    # Let Terminal.app handle TTY setup naturally
    osascript <<APPLESCRIPT
tell application "Terminal"
    activate
    do script "bash '${WRAPPER_SCRIPT}'"
end tell
APPLESCRIPT
    
    echo "Terminal window opened for wrapper: $WRAPPER_SCRIPT" >> "$RUN_LOG"
    
    # Poll until the marker file is removed (indicates Terminal was closed)
    echo "Waiting for aider to complete in Terminal window..."
    echo "  [Instance: ${INSTANCE_ID}] Terminal window opened. Aider will auto-close after completion." >&2
    
    # Wait a moment for the wrapper to start and create the marker file
    sleep 2
    
    # The wrapper creates a marker file and removes it on exit (via trap)
    # When aider exits and the auto-close timer completes, the trap fires and removes the marker
    WAIT_COUNT=0
    MAX_WAIT=3600  # Maximum wait time: 1 hour (3600 * 2 seconds = 2 hours total)
    while true; do
        # Check if marker file still exists
        if [ -f "$MARKER_FILE" ]; then
            # Still active
            WAIT_COUNT=$((WAIT_COUNT + 1))
            if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
                echo "WARNING: Timeout waiting for Terminal to close. Forcing continuation..." >> "$RUN_LOG"
                echo "  [Instance: ${INSTANCE_ID}] Timeout reached. Forcing continuation..." >&2
                # Remove marker file to break the loop
                rm -f "$MARKER_FILE" || true
                break
            fi
            sleep 2
        else
            # Marker removed, terminal closed
            echo "Terminal closed (marker file removed), continuing..." >> "$RUN_LOG"
            echo "  [Instance: ${INSTANCE_ID}] Aider completed. Continuing to next entry..." >&2
            break
        fi
    done

else
    # Non-macOS or no osascript available: fallback to non-interactive behavior
    # Try expect/pty paths as before; prefer a simple --genius-task invocation
    if command -v expect >/dev/null 2>&1; then
        # Use expect-based pty runner to supply the task; keep existing lightweight path
        EXPECT_SCRIPT="${OUT_DIR}/${INSTANCE_ID}.send_task.exp"
        cat > "$EXPECT_SCRIPT" <<'EXPECT'
#!/usr/bin/expect -f
set timeout 1800
set aide_cmd [lindex $argv 0]
set aide_args [lindex $argv 1]
set task_file [lindex $argv 2]
spawn -noecho $aide_cmd {*}$aide_args
expect {
    -re {Genius Agent} { }
    -re {Advanced AI-Powered Pair Programming} { }
    timeout { }
}
set fp [open $task_file r]
set task [read $fp]
close $fp
send -- "$task\r"
expect {
    -re {Genius Agent - Phase: Done} { }
    eof { }
    timeout { }
}
send -- "/exit\r"
expect eof
EXPECT
        chmod +x "$EXPECT_SCRIPT"
        AIDER_BIN="${AIDER_CMD[0]}"
        AIDER_ARGS=""
        for i in "${AIDER_CMD[@]:1}"; do
            AIDER_ARGS+=" $i"
        done
        AIDER_ARGS+=" --genius --yes --auto-commits --no-suggest-shell-commands --no-gitignore ."
        expect -f "$EXPECT_SCRIPT" "$AIDER_BIN" "$AIDER_ARGS" "$AIDER_INPUT_FILE" > "$AIDER_LOG_FILE" 2>&1 || true
    else
        # Last resort (non-interactive): pass task via --genius-task
        "${AIDER_CMD[@]}" --genius --genius-task "$TASK_CONTENT" --yes --auto-commits --no-suggest-shell-commands . > "$AIDER_LOG_FILE" 2>&1 || true
    fi
fi


# Change to the repository directory to capture diffs
echo "Changing to repository directory for diff capture: $REPO_DIR" >> "$RUN_LOG"
cd "$REPO_DIR" || {
    echo "ERROR: Could not change to repo directory: $REPO_DIR" >> "$RUN_LOG"
    exit 1
}

# Clean up all generated scripts and temporary files before capturing diff
echo "Cleaning up generated scripts and temp files..." >> "$RUN_LOG"

# KEEP wrapper script for debugging - DON'T remove it
# if [ -f "$WRAPPER_SCRIPT" ]; then
#     rm -f "$WRAPPER_SCRIPT" || true
#     echo "Removed wrapper script: $WRAPPER_SCRIPT" >> "$RUN_LOG"
# fi
echo "Keeping wrapper for debugging: $WRAPPER_SCRIPT" >> "$RUN_LOG"

# Remove any .oneline files
find "$OUT_DIR" -name "*.oneline" -type f -delete 2>/dev/null || true
echo "Removed .oneline files" >> "$RUN_LOG"

# Remove any aider-generated files in the repo that shouldn't be in the diff
rm -f .aider* 2>/dev/null || true
echo "Removed .aider* files from repo" >> "$RUN_LOG"

# If there are uncommitted changes in the repo, capture git diff
if ! git diff --quiet; then
    git diff > "$DIFF_FILE" || true
    echo "Captured git diff to: $DIFF_FILE" >> "$RUN_LOG"
else
    echo "No uncommitted changes found in repo" >> "$RUN_LOG"
    # Create empty diff file
    touch "$DIFF_FILE"
fi

# Also try to capture last commit message if auto-commits used
LAST_COMMIT_FILE="${LOG_PREFIX}.lastcommit.txt"
if git rev-parse --verify --quiet HEAD >/dev/null; then
    git --no-pager log -1 --pretty=oneline > "$LAST_COMMIT_FILE" || true
    echo "Captured last commit to: $LAST_COMMIT_FILE" >> "$RUN_LOG"
fi

echo "Aider log: $AIDER_LOG_FILE"
echo "Diff file: $DIFF_FILE"
echo "Last commit file: $LAST_COMMIT_FILE"
echo "=== run_test.sh end: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

popd >/dev/null

exit 0
