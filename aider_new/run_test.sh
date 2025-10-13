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

# Checkout the provided commit
if git rev-parse --verify --quiet "$BASE_COMMIT" >/dev/null; then
    git checkout --force "$BASE_COMMIT" || true
else
    # try to fetch and checkout
    git fetch --all --quiet || true
    git checkout --force "$BASE_COMMIT" || true
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

# Read problem content and pass via --genius-task to avoid interactive stdin cancellation
TASK_CONTENT=""
if [ -f "$AIDER_INPUT_FILE" ]; then
    # read file content preserving newlines
    TASK_CONTENT=$(cat "$AIDER_INPUT_FILE") || TASK_CONTENT=""
fi

echo "--- TASK (truncated 1024 chars) ---" >> "$RUN_LOG"
echo "${TASK_CONTENT:0:1024}" >> "$RUN_LOG"
echo "--- END TASK ---" >> "$RUN_LOG"

# # If expect is installed, spawn aider in a pty and send the task after startup
# if command -v expect >/dev/null 2>&1; then
#     EXPECT_SCRIPT="${OUT_DIR}/${INSTANCE_ID}.send_task.exp"
#     cat > "$EXPECT_SCRIPT" <<'EXPECT'
# #!/usr/bin/expect -f
# set timeout 1800
# set aide_cmd [lindex $argv 0]
# set aide_args [lindex $argv 1]
# set task_file [lindex $argv 2]

# # spawn the aider process (command and args passed as single strings)
# spawn -noecho $aide_cmd {*}$aide_args

# # wait for an initial startup marker before sending the task
# expect {
#     -re {Genius Agent} { }
#     -re {Advanced AI-Powered Pair Programming} { }
#     timeout { }
# }

# # read the task file content
# set fp [open $task_file r]
# set task [read $fp]
# close $fp

# # send the task (followed by a newline)
# send -- "$task\r"

# # Wait for the Genius Agent completion marker, EOF, or timeout
# expect {
#     -re {Genius Agent - Phase: Done} { }
#     eof { }
#     timeout { }
# }

# # After completion is observed (or timeout/EOF), send the exit command to terminate cleanly
# send -- "/exit\r"

# # wait for the process to exit
# expect eof
# EXPECT
#     chmod +x "$EXPECT_SCRIPT"
#     # Build args: AIDER_CMD (first element) and rest as a single string of args
#     AIDER_BIN="${AIDER_CMD[0]}"
#     # reconstruct args for expect (everything after the first element)
#     AIDER_ARGS=""
#     for i in "${AIDER_CMD[@]:1}"; do
#         AIDER_ARGS+=" $i"
#     done
#     AIDER_ARGS+=" --genius --yes --auto-commits --no-suggest-shell-commands --no-gitignore ."
#     # run expect and capture output
#     expect -f "$EXPECT_SCRIPT" "$AIDER_BIN" "$AIDER_ARGS" "$AIDER_INPUT_FILE" > "$AIDER_LOG_FILE" 2>&1 || true
# else
#     # fallback: pass task via --genius-task
#     "${AIDER_CMD[@]}" --genius --genius-task "$TASK_CONTENT" --yes --auto-commits --no-suggest-shell-commands . > "$AIDER_LOG_FILE" 2>&1 || true
# fi

# If expect is installed, spawn aider in a pty and send the task after startup
# if command -v expect >/dev/null 2>&1; then
#     EXPECT_SCRIPT="${OUT_DIR}/${INSTANCE_ID}.send_task.exp"
#     cat > "$EXPECT_SCRIPT" <<'EXPECT'
# #!/usr/bin/expect -f
# set timeout 1800
# # first arg is the binary, rest (1..n-1) are aide args, final arg is the task file
# if { $argc < 2 } {
#     puts stderr "usage: $argv0 <aide_bin> <aide_args...> <task_file>"
#     exit 2
# }

# set aide_cmd [lindex $argv 0]
# set task_file [lindex $argv end]
# set aide_args [lrange $argv 1 end-1]

# # spawn the aider process inside a pty with its args
# spawn -noecho $aide_cmd {*}$aide_args

# # wait for an initial startup marker before sending the task
# expect {
#     -re {Genius Agent} { }
#     -re {Advanced AI-Powered Pair Programming} { }
#     -re {Using gpt-} { }        ;# fallback marker
#     timeout { }
# }

# # read the task file content
# set fp [open $task_file r]
# set task [read $fp]
# close $fp

# # send the task (followed by a newline)
# send -- "$task\r"

# # Wait for done; if cancelled, try resending task once
# set resent 0
# expect {
#     -re {Genius Agent - Phase: Done} { }
#     -re {Task input cancelled by user} {
#         # if { $resent == 0 } {
#         #     incr resent
#         #     send -- "$task\r"
#         #     exp_continue
#         # }
#     }
#     timeout { }
#     eof { }
# }

# # Attempt graceful exit
# send -- "/exit\r"

# # wait for the process to exit (short grace period)
# set timeout 10
# expect eof
# EXPECT
#     chmod +x "$EXPECT_SCRIPT"

#     # AIDER_BIN is the command (first element), the rest are real args (preserve array)
#     AIDER_BIN="${AIDER_CMD[0]}"

#     # Call expect passing aide binary followed by each argument separately, then the extra flags, then the task file.
#     expect -f "$EXPECT_SCRIPT" \
#         "$AIDER_BIN" \
#         "${AIDER_CMD[@]:1}" \
#         --genius --yes --auto-commits --no-suggest-shell-commands --no-gitignore . \
#         "$AIDER_INPUT_FILE" > "$AIDER_LOG_FILE" 2>&1 || true
# else
    # Fallback: use Python PTY runner to keep interactive TTY even without expect
    # Requires pty_run.py in the same directory as this script
    PTY_RUN="$(dirname "$0")/pty_run.py"
    if command -v python3 >/dev/null 2>&1 && [ -f "$PTY_RUN" ]; then
        # Build the full command line: AIDER_CMD args + our flags + repo path
        # Note: pass them after -- so pty_run treats them as the child command
        python3 "$PTY_RUN" \
            --task-file "$AIDER_INPUT_FILE" \
            --startup-timeout 60 \
            --done-timeout 1800 \
            -- "${AIDER_CMD[@]}" --genius --yes --auto-commits --no-suggest-shell-commands --no-gitignore . \
            > "$AIDER_LOG_FILE" 2>&1 || true
    else
        # Last resort (non-interactive): pass task via --genius-task
        "${AIDER_CMD[@]}" --genius --genius-task "$TASK_CONTENT" --yes --auto-commits --no-suggest-shell-commands . > "$AIDER_LOG_FILE" 2>&1 || true
    fi
# fi


# If there are uncommitted changes, capture git diff
if ! git diff --quiet; then
    git diff > "$DIFF_FILE" || true
fi

# Also try to capture last commit message if auto-commits used
LAST_COMMIT_FILE="${LOG_PREFIX}.lastcommit.txt"
if git rev-parse --verify --quiet HEAD >/dev/null; then
    git --no-pager log -1 --pretty=oneline > "$LAST_COMMIT_FILE" || true
fi

echo "Aider log: $AIDER_LOG_FILE"
echo "Diff file: $DIFF_FILE"
echo "Last commit file: $LAST_COMMIT_FILE"
echo "=== run_test.sh end: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

popd >/dev/null

exit 0
