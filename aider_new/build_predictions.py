#!/usr/bin/env python3
"""
Build predictions.jsonl from patch .diff files.

- instance_id: the subfolder name (e.g., "astropy__astropy-7746")
- model_name_or_path: fixed to "gpt-4o"
- model_patch: content of the .diff file in that subfolder

Usage:
    python build_predictions.py --root /path/to/aider_new/outputs --out predictions.jsonl
"""

import argparse
import json
import sys
from pathlib import Path

def find_first_diff(dirpath: Path) -> Path | None:
    diffs = sorted(dirpath.glob("*.diff"))
    return diffs[0] if diffs else None

def main():
    parser = argparse.ArgumentParser(description="Create JSONL predictions from .diff files.")
    parser.add_argument("--root", type=Path, required=True,
                        help="Root directory containing subfolders (e.g., aider_new/outputs).")
    parser.add_argument("--out", type=Path, default=Path("predictions.jsonl"),
                        help="Output JSONL file path (default: predictions.jsonl).")
    parser.add_argument("--model", default="gpt-4o",
                        help='Value for "model_name_or_path" (default: gpt-4o).')

    args = parser.parse_args()

    if not args.root.exists() or not args.root.is_dir():
        print(f"Error: root path {args.root} does not exist or is not a directory.", file=sys.stderr)
        sys.exit(1)

    # Collect subdirectories (instance_ids)
    subdirs = sorted([p for p in args.root.iterdir() if p.is_dir()])

    if not subdirs:
        print(f"Warning: No subdirectories found under {args.root}. Nothing to do.", file=sys.stderr)

    written = 0
    skipped = 0

    with args.out.open("w", encoding="utf-8") as fout:
        for sub in subdirs:
            instance_id = sub.name
            diff_path = find_first_diff(sub)

            if diff_path is None:
                skipped += 1
                print(f"[skip] No .diff file in {sub}", file=sys.stderr)
                continue

            patch_text = diff_path.read_text(encoding="utf-8", errors="replace")

            record = {
                "instance_id": instance_id,
                "model_name_or_path": args.model,
                "model_patch": patch_text,
            }

            # Write one JSON object per line
            fout.write(json.dumps(record, ensure_ascii=False) + "\n")
            written += 1

    print(f"Done. Wrote {written} records to {args.out}. Skipped {skipped} subfolders without .diff.")

if __name__ == "__main__":
    main()
