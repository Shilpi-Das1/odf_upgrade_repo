#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create New Feature Subtasks for ODF v4.23

Reads new_features_4.23.txt (format: task_name|task_description per line)
and creates a Jira Sub-Task under a given parent for each entry.

All configurable fields have built-in defaults but can be overridden via a
single optional JSON config file passed with --config:

  {
    "parent_key":      "CSOP-891",
    "fix_version":     "ODF v4.23.0",
    "affects_version": "ODF v4.23.0",
    "component":       "ODF QE",
    "label":           "odf-new-feature"
  }

Any key that is omitted falls back to the default value shown above.

Usage:
    python scripts/create_new_feature_subtasks.py
    python scripts/create_new_feature_subtasks.py --config custom.json
    python scripts/create_new_feature_subtasks.py --features-file path/to/features.txt
    python scripts/create_new_feature_subtasks.py --dry-run
"""

import sys
import os
import argparse
from pathlib import Path

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# Allow running from the repo root or the scripts/ directory
sys.path.insert(0, str(Path(__file__).parent))

from jira_utils import JiraHelper  # noqa: E402  (import after path fix)

# ---------------------------------------------------------------------------
# Defaults  (all overridable via --config JSON)
# ---------------------------------------------------------------------------

DEFAULTS = {
    "parent_key":      "task_id",
    "fix_version":     "ODF v4.23.0",
    "affects_version": "ODF v4.23.0",
    "component":       "ODF",
    "label":           "odf-new-feature",
}

DEFAULT_FEATURES_FILE = Path(__file__).parent.parent / "new_features_4.23.txt"


def load_config(config_path: str | None) -> dict:
    """
    Load optional JSON config and merge with DEFAULTS.
    Only the five recognised keys are applied; unknown keys are ignored.
    """
    import json
    cfg = dict(DEFAULTS)
    if config_path:
        path = Path(config_path)
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {config_path}")
        with open(path, encoding="utf-8") as fh:
            overrides = json.load(fh)
        for key in DEFAULTS:
            if key in overrides:
                cfg[key] = overrides[key]
        print(f"✓ Loaded config overrides from: {config_path}")
    return cfg


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_features_file(features_file: Path) -> list[dict]:
    """
    Parse features file into a list of {'name': ..., 'description': ...} dicts.

    Lines are expected to be:   task_name|task_description
    Empty lines and lines that do not contain '|' are skipped.
    """
    features = []
    with open(features_file, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, start=1):
            line = raw.strip()
            if not line or "|" not in line:
                continue
            name, _, description = line.partition("|")
            name = name.strip()
            description = description.strip()
            if not name:
                print(f"  ⚠ Line {lineno}: empty task name, skipping")
                continue
            features.append({"name": name, "description": description})
    return features


def build_subtask_description(task_description: str) -> str:
    """Build the Jira description body for a new-feature subtask."""
    return task_description if task_description else ""


# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

def create_feature_subtasks(features_file: Path, cfg: dict, dry_run: bool = False) -> int:
    """
    Create one Sub-Task per feature under cfg['parent_key'].

    Returns the number of subtasks successfully created (or would-be created
    in dry-run mode).
    """
    parent_key      = cfg["parent_key"]
    fix_version     = cfg["fix_version"]
    affects_version = cfg["affects_version"]
    component       = cfg["component"]
    label           = cfg["label"]

    print("=" * 60)
    print("ODF New Feature Subtask Creator")
    print("=" * 60)
    print(f"  Features file    : {features_file}")
    print(f"  Parent           : {parent_key}")
    print(f"  Fix Version      : {fix_version}")
    print(f"  Affects Version  : {affects_version}")
    print(f"  Component        : {component}")
    print(f"  Label            : {label}")
    if dry_run:
        print("  Mode             : DRY RUN (no Jira changes will be made)")
    print()

    # Parse input file
    features = parse_features_file(features_file)
    if not features:
        print("✗ No features found in the file. Exiting.")
        return 0

    print(f"✓ Parsed {len(features)} feature(s) from {features_file.name}\n")

    if dry_run:
        for idx, feat in enumerate(features, start=1):
            print(f"  [{idx:02d}] {feat['name']}")
            if feat["description"]:
                print(f"       → {feat['description']}")
        print(f"\nDry run complete. {len(features)} subtask(s) would be created.")
        return len(features)

    # Connect to Jira via JiraHelper
    helper = JiraHelper()
    jira = helper.jira

    # Resolve the parent issue once
    try:
        parent = jira.issue(parent_key)
        print(f"✓ Parent issue : {parent_key} — {parent.fields.summary}")
    except Exception as exc:
        raise ValueError(f"Cannot fetch parent issue {parent_key}: {exc}") from exc

    project_key = parent.fields.project.key

    created = 0
    skipped = 0
    failed = 0

    for idx, feat in enumerate(features, start=1):
        task_name = feat["name"]
        task_description = feat["description"]

        print(f"\n[{idx:02d}/{len(features):02d}] {task_name}")

        # --- duplicate check ------------------------------------------------
        jql = f'parent = {parent_key} AND issuetype = Sub-Task AND summary ~ "{task_name}"'
        try:
            existing = jira.search_issues(jql, maxResults=10)
            exact = [i for i in existing if i.fields.summary == task_name]
            if exact:
                print(f"  ⚠ Already exists: {exact[0].key} — skipping")
                skipped += 1
                continue
        except Exception as exc:
            print(f"  ⚠ Duplicate check failed ({exc}), proceeding with creation")

        # --- build fields ---------------------------------------------------
        description_text = build_subtask_description(task_description)

        issue_fields = {
            "project":     {"key": project_key},
            "summary":     task_name,
            "issuetype":   {"id": "10400"},          # Sub-Task
            "parent":      {"key": parent_key},
            "description": description_text,
            "components":  [{"name": component}],
            "labels":      [label],
            "fixVersions": [{"name": fix_version}],
            "versions":    [{"name": affects_version}],
        }

        # --- create ---------------------------------------------------------
        try:
            new_issue = jira.create_issue(fields=issue_fields)
            print(f"  ✓ Created: {new_issue.key}")
            print(f"     URL: {helper.jira_server.rstrip('/')}/browse/{new_issue.key}")
            created += 1
        except Exception as exc:
            err = str(exc)
            # Some fields may not be on the create screen; retry with minimal fields
            if "cannot be set" in err.lower() or "not on the appropriate screen" in err.lower():
                print(f"  ⚠ Some fields not on create screen, retrying with minimal fields...")
                minimal_fields = {
                    "project":   {"key": project_key},
                    "summary":   task_name,
                    "issuetype": {"id": "10400"},
                    "parent":    {"key": parent_key},
                }
                try:
                    new_issue = jira.create_issue(fields=minimal_fields)
                    # Update optional fields one-by-one
                    for field, value in {
                        "description": description_text,
                        "components":  [{"name": component}],
                        "labels":      [label],
                        "fixVersions": [{"name": fix_version}],
                        "versions":    [{"name": affects_version}],
                    }.items():
                        try:
                            new_issue.update(fields={field: value})
                        except Exception as upd_err:
                            print(f"  ⚠ Could not set '{field}': {upd_err}")
                    print(f"  ✓ Created: {new_issue.key}")
                    print(f"     URL: {helper.jira_server.rstrip('/')}/browse/{new_issue.key}")
                    created += 1
                except Exception as exc2:
                    print(f"  ✗ Failed: {exc2}")
                    failed += 1
            else:
                print(f"  ✗ Failed: {err}")
                failed += 1

    # --- summary ---
    print("\n" + "=" * 60)
    print(f"Done.  Created: {created}  |  Skipped: {skipped}  |  Failed: {failed}")
    print("=" * 60)
    return created


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create Jira Sub-Tasks for ODF new features",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Config file (JSON) — all keys are optional, unset keys use the default:
  {
    "parent_key":      "CSOP-891",
    "fix_version":     "ODF v4.23.0",
    "affects_version": "ODF v4.23.0",
    "component":       "ODF QE",
    "label":           "odf-new-feature"
  }
        """,
    )
    parser.add_argument(
        "--features-file",
        default=str(DEFAULT_FEATURES_FILE),
        help=f"Path to the features text file (default: {DEFAULT_FEATURES_FILE})",
    )
    parser.add_argument(
        "--config",
        default=None,
        help="Optional JSON config file to override parent_key / versions / component / label",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse the file and print what would be created without touching Jira",
    )
    args = parser.parse_args()

    features_file = Path(args.features_file)
    if not features_file.exists():
        print(f"✗ Features file not found: {features_file}", file=sys.stderr)
        return 1

    try:
        cfg = load_config(args.config)
        create_feature_subtasks(features_file, cfg, dry_run=args.dry_run)
        return 0
    except Exception as exc:
        print(f"\n✗ Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

# Made with Bob
