#!/usr/bin/env python3
"""
run_exp.py

Reads a JSON array file (`test_data.json`) where each element contains keys:
 - repo: e.g. "astropy/astropy"
 - base_commit: commit hash to checkout
 - instance_id: unique id
 - problem_statement: text

For each entry it:
 - clones the repo into a temp workspace (or reuses existing)
 - writes problem statement to a temporary problem.txt
 - invokes `run_test.sh <repo_dir> <base_commit> <instance_id> <out_dir>`
 - captures the generated diff (if any) and writes a JSONL line to `predictions.jsonl` with
   {"instance_id": ..., "model_name_or_path": "aider-local", "model_patch": "<patch>"}

Note: this script expects `git`, `bash`, and `conda` (optional) to be available.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parent
TEST_DATA = ROOT / "test_data.json"
OUT_ROOT = ROOT / "outputs"
REPOS_ROOT = OUT_ROOT / "repos"
PREDICTIONS_FILE = OUT_ROOT / "predictions.jsonl"
RUN_SCRIPT = ROOT / "run_test.sh"
ORCH_LOG = OUT_ROOT / "orchestrator.log"


def load_tests(path: Path):
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return data


def run_cmd(cmd, cwd=None, env=None, capture_output=False):
    # append command and outputs to orchestrator log
    with open(ORCH_LOG, "a", encoding="utf-8") as lf:
        lf.write("\n--- RUN: {} (cwd={}) ---\n".format(" ".join(cmd), cwd))
        lf.flush()
        res = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=capture_output)
        if capture_output:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
            lf.write(res.stdout or "")
            lf.write(res.stderr or "")
        else:
            # if not capturing, still record return code
            lf.write(f"Returncode: {res.returncode}\n")
        lf.flush()
    return res


def clone_repo(repo_full: str, dest: Path):
    if dest.exists():
        # Check if it's actually a valid git repo
        git_dir = dest / ".git"
        if git_dir.exists():
            # It's a git repo; fetch all to get specific commits
            run_cmd(["git", "-C", str(dest), "fetch", "--all"], capture_output=True)
        else:
            # Directory exists but not a git repo; remove and clone fresh
            print(f"Directory {dest} exists but is not a git repo. Removing and cloning fresh...")
            shutil.rmtree(dest)
            # Clone without depth limitation so we can checkout specific commits
            run_cmd(["git", "clone", f"https://github.com/{repo_full}.git", str(dest)])
    else:
        # Clone without depth limitation so we can checkout specific commits
        run_cmd(["git", "clone", f"https://github.com/{repo_full}.git", str(dest)])


def write_problem(out_dir: Path, problem_text: str):
    out_dir.mkdir(parents=True, exist_ok=True)
    prob_file = out_dir / "problem.txt"
    # Ensure the problem text ends with a single trailing newline.
    # Do NOT append control commands such as "/exit"; those were being
    # interpreted by aider as a user cancellation.
    if problem_text and problem_text.strip():
        content = problem_text.rstrip() + "\n"
    else:
        # minimal placeholder (blank line) so file exists but contains no commands
        content = "\n"
    prob_file.write_text(content, encoding="utf-8")
    # record to orchestrator log what we wrote (first 200 chars)
    with open(ORCH_LOG, "a", encoding="utf-8") as lf:
        lf.write(f"WROTE PROBLEM for {prob_file}: {content[:200]}\n")
    return prob_file


def process_entry(entry, workspace: Path):
    repo = entry.get("repo")
    base_commit = entry.get("base_commit")
    instance_id = entry.get("instance_id")
    problem = entry.get("problem_statement") or entry.get("problem") or ""

    repo_name = repo.replace("/", "_")
    repo_dir = REPOS_ROOT / f"{repo_name}"
    out_dir = OUT_ROOT / instance_id
    out_dir.mkdir(parents=True, exist_ok=True)

    # write orchestrator per-instance header
    with open(ORCH_LOG, "a", encoding="utf-8") as lf:
        lf.write(f"\n===== Processing {instance_id} =====\n")
        lf.flush()

    print(f"Processing {instance_id}: cloning {repo} into {repo_dir}")
    try:
        clone_repo(repo, repo_dir)
    except Exception as e:
        print("Failed to clone", e)
        # write empty prediction
        return {"instance_id": instance_id, "model_name_or_path": "aider-local", "model_patch": ""}

    # checkout commit
    run_cmd(["git", "-C", str(repo_dir), "fetch", "--all"], capture_output=True)
    run_cmd(["git", "-C", str(repo_dir), "checkout", "--force", base_commit], capture_output=True)

    # write problem file
    write_problem(out_dir, problem)

    # call run_test.sh
    # redirect run_test.sh stdout/stderr to per-instance run log (run_test.sh also tees there)
    res = run_cmd(["bash", str(RUN_SCRIPT), str(repo_dir), base_commit, instance_id, str(out_dir)], capture_output=True)
    # write run_test.sh output summary to orchestrator log
    with open(ORCH_LOG, "a", encoding="utf-8") as lf:
        lf.write(f"run_test.sh exit code: {res.returncode}\n")
        if res.stdout:
            lf.write("STDOUT:\n" + res.stdout + "\n")
        if res.stderr:
            lf.write("STDERR:\n" + res.stderr + "\n")
        lf.flush()
    if res.returncode != 0:
        print("run_test.sh failed for", instance_id, "see outputs in", out_dir)

    # read diff if present
    diff_path = out_dir / f"{instance_id}.diff"
    patch_text = ""
    if diff_path.exists():
        patch_text = diff_path.read_text(encoding="utf-8")
    else:
        # attempt to read aider log and find diff
        log_path = out_dir / f"{instance_id}.aider.log"
        if log_path.exists():
            # heuristic: look for 'diff --git' blocks
            txt = log_path.read_text(encoding="utf-8")
            idx = txt.find("diff --git")
            if idx != -1:
                patch_text = txt[idx:]

    return {"instance_id": instance_id, "model_name_or_path": "aider-local", "model_patch": patch_text}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instance", "-i", help="Run only the entry with this instance_id")
    args = parser.parse_args()

    if not TEST_DATA.exists():
        print("test_data.json not found at", TEST_DATA)
        sys.exit(1)

    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    REPOS_ROOT.mkdir(parents=True, exist_ok=True)

    entries = load_tests(TEST_DATA)

    # If an instance id is provided, filter to that single entry
    if args.instance:
        entries = [e for e in entries if e.get("instance_id") == args.instance]
        if not entries:
            print(f"No entry with instance_id={args.instance} found in {TEST_DATA}")
            sys.exit(1)

    with open(PREDICTIONS_FILE, "w", encoding="utf-8") as outf:
        for entry in entries:
            pred = process_entry(entry, REPOS_ROOT)
            json_line = json.dumps(pred, ensure_ascii=False)
            outf.write(json_line + "\n")
            outf.flush()
            print("Wrote prediction for", pred["instance_id"])

    print("All done. Predictions at", PREDICTIONS_FILE)


if __name__ == "__main__":
    main()
