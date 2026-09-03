#!/usr/bin/env python3
"""Validate .cursor-plugin/marketplace.json for the RazorMetrics marketplace.

Pure standard library (no dependencies). Mirrors the Cursor marketplace schema
(https://raw.githubusercontent.com/cursor/plugins/main/schemas/marketplace.schema.json)
and additionally verifies that every plugin `source` resolves to a real plugin
directory whose manifest `name` matches the marketplace entry `name`.

Usage:
    python3 validate_marketplace.py [REPO_ROOT]

REPO_ROOT defaults to the nearest ancestor of the current directory that
contains .cursor-plugin/marketplace.json.
"""
import json
import re
import sys
from pathlib import Path

KEBAB = re.compile(r"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$")
ENTRY_ALLOWED = {"name", "source", "description", "minClientVersions"}
TOP_ALLOWED = {"name", "owner", "metadata", "plugins"}


def find_repo_root(start: Path) -> Path | None:
    # Pick the TOPMOST ancestor that holds a root marketplace manifest, so a nested
    # vendored marketplace.json (e.g. inside an imported collection) is never mistaken
    # for the repo root.
    match = None
    for d in [start, *start.parents]:
        if (d / ".cursor-plugin" / "marketplace.json").is_file():
            match = d
    return match


def main() -> int:
    start = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    root = find_repo_root(start)
    if root is None:
        print("FAIL: could not locate .cursor-plugin/marketplace.json")
        return 1

    manifest_path = root / ".cursor-plugin" / "marketplace.json"
    try:
        mf = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as e:
        print(f"FAIL: {manifest_path} is not valid JSON: {e}")
        return 1

    errors: list[str] = []

    for key in mf:
        if key not in TOP_ALLOWED:
            errors.append(f"top-level: unexpected key '{key}'")
    if not isinstance(mf.get("name"), str) or not mf.get("name"):
        errors.append("top-level: 'name' is required and must be a non-empty string")
    if "owner" in mf:
        owner = mf["owner"]
        if not isinstance(owner, dict) or not owner.get("name"):
            errors.append("owner: must be an object with a non-empty 'name'")
    plugins = mf.get("plugins")
    if not isinstance(plugins, list):
        errors.append("top-level: 'plugins' is required and must be an array")
        plugins = []

    seen: set[str] = set()
    for i, p in enumerate(plugins):
        loc = f"plugins[{i}]"
        if not isinstance(p, dict):
            errors.append(f"{loc}: must be an object")
            continue
        for key in p:
            if key not in ENTRY_ALLOWED:
                errors.append(f"{loc}: unexpected key '{key}' (put keywords/category/tags in the plugin's plugin.json)")
        name = p.get("name")
        source = p.get("source")
        if not name or not isinstance(name, str):
            errors.append(f"{loc}: 'name' is required")
            continue
        loc = f"plugins[{i}] '{name}'"
        if not KEBAB.match(name):
            errors.append(f"{loc}: name must be kebab-case ({KEBAB.pattern})")
        if name in seen:
            errors.append(f"{loc}: duplicate plugin name")
        seen.add(name)
        if not source or not isinstance(source, str):
            errors.append(f"{loc}: 'source' is required")
            continue
        src = root / source
        if not src.is_dir():
            errors.append(f"{loc}: source directory does not exist: {source}")
            continue
        manifest = src / "plugin.json"
        if not manifest.is_file():
            manifest = src / ".cursor-plugin" / "plugin.json"
        if not manifest.is_file():
            errors.append(f"{loc}: no plugin.json or .cursor-plugin/plugin.json in {source}")
            continue
        try:
            data = json.loads(manifest.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"{loc}: {manifest} is not valid JSON: {e}")
            continue
        if data.get("name") != name:
            errors.append(f"{loc}: entry name '{name}' != manifest name '{data.get('name')}' in {manifest.relative_to(root)}")
        else:
            print(f"  OK  {name:28s} source={source}")

    print()
    if errors:
        print(f"FAIL: {len(errors)} problem(s) in {manifest_path.relative_to(root)}")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"PASS: {manifest_path.relative_to(root)} valid — {len(plugins)} plugin(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
