#!/usr/bin/env bash
set -euo pipefail
INSTANCE_ID='astropy__astropy-6938'
TASK_FILE='/Users/jayanaka-98/Repos/PromptCompEval/aider_new/outputs/astropy__astropy-6938/problem.txt'
REPO_DIR='/Users/jayanaka-98/Repos/PromptCompEval/aider_new/outputs/repos/astropy_astropy'
printf '\033]0;%s\007' "AIDER:${INSTANCE_ID}"
echo "===== AIDER interactive session: ${INSTANCE_ID} ====="
echo "Task (first 1024 chars):"
head -c 1024 "${TASK_FILE}" || true
echo
echo "Launching aider (interactive). When done, close this window to allow the experiment to continue."
echo
# change to the repository directory so aider runs with a git repo
if [ -n "${REPO_DIR}" ] && [ -d "${REPO_DIR}" ]; then
    cd "${REPO_DIR}" || true
    echo "Changed directory to ${REPO_DIR}"
else
    echo "Repository directory '${REPO_DIR}' not found; running in current directory"
fi
CMD='conda run -n aider python -m aider.main '
# When running in Terminal.app (already has a PTY), run aider directly and pass task via stdin
# Read the task and pipe it into aider
echo "Running aider interactively in Terminal (has PTY)..."
cat "${TASK_FILE}" | eval "${CMD} --genius --yes --auto-commits --no-suggest-shell-commands --no-gitignore ."
echo
echo "Aider process exited. Inspect the repo/commits. Close this window to continue the pipeline."
# keep an interactive shell so user can inspect before closing
exec "$SHELL" -l
