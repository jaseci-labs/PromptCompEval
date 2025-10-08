#!/bin/bash
set -e

REPO_URL=$1
COMMIT_HASH=$2
TEST_CMD=$3
PROBLEM_STATEMENT="$4"

# Initialize conda for this script
eval "$(conda shell.bash hook)"

###############################################
# 1. Clone target repository
###############################################
echo "Cloning repository: $REPO_URL"
git clone $REPO_URL repo
cd repo
echo "Checking out commit: $COMMIT_HASH"
git checkout $COMMIT_HASH

###############################################
# 2. Create a CONDA environment for the target repo
#    This prevents aider-genius (in its own env) deps from colliding with
#    the project's required dependency versions.
###############################################
SLUG_RAW="$(basename "$REPO_URL")"
SLUG_NO_GIT="${SLUG_RAW%.git}"
REPO_ENV_NAME="${SLUG_NO_GIT}_${COMMIT_HASH:0:8}"

echo "Creating conda environment: $REPO_ENV_NAME"

# Detect Python version needed for the repo (default to 3.9 for compatibility)
PYTHON_VERSION="3.9"
if [ -f .python-version ]; then
    PYTHON_VERSION=$(cat .python-version | head -1)
elif [ -f pyproject.toml ] && grep -q "python_requires" pyproject.toml; then
    # Extract python version from pyproject.toml if available
    PYTHON_VERSION="3.9"  # fallback
elif [ -f setup.py ] && grep -q "python_requires" setup.py; then
    # Extract python version from setup.py if available  
    PYTHON_VERSION="3.9"  # fallback
fi

echo "Using Python $PYTHON_VERSION for repo environment"

# Create conda environment for the repo
conda create -n "$REPO_ENV_NAME" python="$PYTHON_VERSION" -y
conda clean -afy

ACTIVATE_REPO_ENV() {
    conda activate "$REPO_ENV_NAME"
}

DEACTIVATE_REPO_ENV() {
    conda deactivate || true
}

echo "Created conda repo environment: $REPO_ENV_NAME"

###############################################
# 3. Install repo/test dependencies INSIDE isolated conda env only
###############################################
ACTIVATE_REPO_ENV
echo "Installing repository dependencies inside isolated conda environment..."

# Always modernize pip/setuptools/wheel first
python -m pip install --upgrade pip setuptools wheel || true

# Detect whether repo appears to need heavy scientific stack
NEEDS_SCI=0
if grep -E -i -q 'numpy|scipy|astropy|cython|matplotlib' requirements.txt 2>/dev/null; then NEEDS_SCI=1; fi
if [ -f pyproject.toml ] && grep -E -i -q 'numpy|scipy|astropy|cython|matplotlib' pyproject.toml; then NEEDS_SCI=1; fi
if [ -f setup.cfg ] && grep -E -i -q 'numpy|scipy|astropy|cython|matplotlib' setup.cfg; then NEEDS_SCI=1; fi
if [ -n "${AIDER_FORCE_SCI:-}" ]; then NEEDS_SCI=1; fi

echo "Heuristic: scientific stack required? $NEEDS_SCI (override with AIDER_FORCE_SCI=1)"

# If requirements.txt exists, install it early (let resolver pick versions)
if [ -f requirements.txt ]; then
    echo "Installing requirements.txt..."
    python -m pip install -r requirements.txt || true
fi

# Minimal test tooling always
python -m pip install pytest pytest-xvfb hypothesis || true

# If heavy scientific deps appear needed, install them with conda for better compatibility
if [ "$NEEDS_SCI" = "1" ]; then
    echo "Installing scientific stack via conda..."
    conda install -c conda-forge numpy scipy matplotlib cython pyerfa pyyaml -y || true
    # Astropy-specific pytest helpers only if astropy detected
    if grep -E -i -q 'astropy' requirements.txt pyproject.toml setup.cfg 2>/dev/null; then
         python -m pip install pytest-astropy pytest-arraydiff pytest-doctestplus pytest-openfiles pytest-remotedata || true
    fi
else
    echo "Skipping heavy scientific stack (not detected)."
fi

echo "Applying compatibility patches (inside repo env) if needed..."
bash /patch_dep_util.sh || true

if [ -f setup.py ] || [ -f pyproject.toml ]; then
    echo "Attempting editable install of repo inside isolated env..."
    # Allow disabling editable install with AIDER_SKIP_EDITABLE=1
    if [ -n "${AIDER_SKIP_EDITABLE:-}" ]; then
        echo "AIDER_SKIP_EDITABLE set; skipping editable install"
    else
        if SETUPTOOLS_SCM_PRETEND_VERSION=4.3.0 pip install -e ".[test]" --verbose 2>/dev/null; then
            echo "Repo installed with test extras"
        elif SETUPTOOLS_SCM_PRETEND_VERSION=4.3.0 pip install --no-build-isolation -e . 2>/dev/null; then
            echo "Repo installed without build isolation"
        elif SETUPTOOLS_SCM_PRETEND_VERSION=4.3.0 pip install --no-deps -e . 2>/dev/null; then
            echo "Repo installed without deps"
        else
            echo "Repo installation failed; proceeding anyway"
        fi
    fi
else
    echo "No setup.py or pyproject.toml; skipping repo install"
fi

# Record python path for logs
echo "Repo env Python: $(which python)" >&2

# Provide a wrapper script to run test commands inside repo conda env
WRAPPER=/workspace/run_tests.sh
cat > "$WRAPPER" <<EOS
#!/bin/bash
set -e
eval "\$(conda shell.bash hook)"
conda activate "$REPO_ENV_NAME"
bash -c "\$@"
EOS
chmod +x "$WRAPPER"

###############################################
# 4. Run baseline tests inside repo env, then deactivate before aider
###############################################

build_k_expr_from_test_cmd() {
    local cmd="$TEST_CMD"
    local expr_parts=()
    # tokenize by space
    for tok in $cmd; do
        # look for pytest node ids like module.Class::test or path::Class::test
        if [[ "$tok" == *"::"* ]]; then
            local left part_class test_name
            left="${tok%%::*}"           # everything before first ::
            test_name="${tok##*::}"      # everything after last ::
            # class name is last dotted or path segment of left
            part_class="${left##*.}"
            part_class="${part_class##*/}"
            # strip quotes if any
            part_class="${part_class%\'}"; part_class="${part_class#\'}"
            test_name="${test_name%\'}"; test_name="${test_name#\'}"
            if [[ -n "$part_class" && -n "$test_name" ]]; then
                expr_parts+=("($part_class and $test_name)")
            fi
        fi
    done
    local IFS=' OR '
    echo "${expr_parts[*]}"
}

run_tests_inside_repo_env() {
    set +e
    bash "$WRAPPER" "$TEST_CMD"
    local code=$?
    # Pytest exit code 5 means no tests collected; retry with -k expression
    if [ $code -eq 5 ]; then
        echo "No tests collected with provided node ids; retrying with -k fallback..." >&2
        local kexpr
        kexpr=$(build_k_expr_from_test_cmd)
        if [ -n "$kexpr" ]; then
            local FALLBACK_CMD
            FALLBACK_CMD="python -m pytest -rA -vv -o console_output_style=classic --tb=short -k \"$kexpr\""
            echo "Fallback command: $FALLBACK_CMD" >&2
            bash "$WRAPPER" "$FALLBACK_CMD"
        else
            echo "Could not derive a -k expression; skipping fallback." >&2
        fi
    fi
    set -e
}

# 5. Prepare logging & test execution (baseline + post-fix)
#    Switch back to base environment for aider execution
DEACTIVATE_REPO_ENV || true

# Run tests, capture logs (tests themselves activate env via function/wrapper)
mkdir -p /workspace/logs
TEST_LOG="/workspace/logs/test_output.log"
DIFF_LOG="/workspace/logs/diff.log"
AIDER_LOG="/workspace/logs/aider.log"

echo "=== Running tests BEFORE aider patch ===" > $TEST_LOG
echo "Repository: $REPO_URL" >> $TEST_LOG
echo "Commit: $COMMIT_HASH" >> $TEST_LOG
echo "Test Command: $TEST_CMD" >> $TEST_LOG
echo "Problem Statement: $PROBLEM_STATEMENT" >> $TEST_LOG
echo "================================" >> $TEST_LOG

# Run baseline tests inside isolated repo environment
echo "Running test command BEFORE aider (isolated conda env): $TEST_CMD"
echo "=== BEFORE AIDER TEST RESULTS ===" >> $TEST_LOG
run_tests_inside_repo_env >> $TEST_LOG 2>&1
echo "=== END BEFORE AIDER TEST RESULTS ===" >> $TEST_LOG

# Activate aider-genius environment for running aider
conda activate aider-genius

# Check if aider-genius CLI is available
if command -v jac-coder &> /dev/null; then
    AIDER_CMD="jac-coder"
    GENIUS_MODE="--genius"
else
    echo "Error: aider-genius CLI (jac-coder) not found in aider-genius conda environment." >> $TEST_LOG
    echo "Aborting aider phase to avoid using global/pip aider." >> $TEST_LOG
    AIDER_CMD=""
    GENIUS_MODE=""
fi

if [ -n "$AIDER_CMD" ]; then
    echo "$AIDER_CMD is available, attempting to fix the issue..."
    echo "=== Running $AIDER_CMD to fix the issue ===" >> $TEST_LOG
    echo "$AIDER_CMD version:" >> $TEST_LOG
    $AIDER_CMD --version >> $TEST_LOG 2>&1 || true
    
    # Use aider to attempt a fix based on the problem statement
    if [ -n "$PROBLEM_STATEMENT" ]; then
        echo "Providing problem statement to aider..." >> $TEST_LOG
        echo "Problem: $PROBLEM_STATEMENT" >> $TEST_LOG
        
        # Create a prompt for aider-genius that includes the failing tests and use genius mode
        AIDER_PROMPT="$PROBLEM_STATEMENT"
        
        # Run aider in genius mode with the problem statement as a task
        echo "Running $AIDER_CMD with genius mode..." >> $AIDER_LOG
        echo "Task: $AIDER_PROMPT" >> $AIDER_LOG
        
        # Use aider with genius mode for enhanced AI capabilities
        MODEL_NAME="${AIDER_MODEL:-gpt-4o}"
        $AIDER_CMD $GENIUS_MODE --yes --auto-commits --model "$MODEL_NAME" --message "$AIDER_PROMPT" --no-suggest-shell-commands . >> $AIDER_LOG 2>&1 || true
        
        # Check if aider made any changes
        if git diff --quiet; then
            echo "Aider did not make any changes" >> $TEST_LOG
        else
            echo "Aider made changes, capturing diff..." >> $TEST_LOG
            git diff > $DIFF_LOG
            echo "=== AIDER GENERATED DIFF ===" >> $TEST_LOG
            cat $DIFF_LOG >> $TEST_LOG
            echo "=== END AIDER GENERATED DIFF ===" >> $TEST_LOG
            
            # Run tests AFTER aider to see if it fixed the issue
            echo "=== Running tests AFTER aider patch (isolated conda env) ===" >> $TEST_LOG
            echo "Running test command AFTER aider: $TEST_CMD" >> $TEST_LOG
            run_tests_inside_repo_env >> $TEST_LOG 2>&1
            echo "=== END AFTER AIDER TEST RESULTS ===" >> $TEST_LOG
        fi
    else
        echo "No problem statement provided, skipping aider" >> $TEST_LOG
    fi
else
    echo "Warning: Aider not found in aider-genius conda environment" >> $TEST_LOG
fi

echo "=== Test execution completed ===" >> $TEST_LOG
echo "Logs saved to /workspace/logs/"