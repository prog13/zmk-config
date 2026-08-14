#!/usr/bin/env python3
"""Print build.yaml targets as name/board/shield/snippet/cmake-args, US-separated.

A tab would not work: bash collapses runs of whitespace separators, so an empty
snippet field would shift cmake-args into it.

Usage: targets.py <name>|--all|--list <build.yaml>
"""

import sys

import yaml

want, path = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(path)) or {}

for entry in doc.get("include", []):
    if "board" not in entry:
        sys.exit("build.yaml: entry without a board: %r" % entry)

    name = entry.get("artifact-name") or "%s-%s" % (entry["board"], entry.get("shield", ""))
    name = name.replace(" ", "_").replace("/", "_")
    if want not in ("--all", "--list", name):
        continue

    fields = [
        name,
        entry["board"],
        entry.get("shield", ""),
        entry.get("snippet", ""),
        entry.get("cmake-args", ""),
    ]
    for f in fields:
        if not isinstance(f, str):
            sys.exit("build.yaml: %s: expected a string, got %r" % (name, f))
    print("\x1f".join(fields))
