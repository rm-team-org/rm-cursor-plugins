#!/usr/bin/env python3
"""
Validate rules/*.mdc layout per repo README: required frontmatter fields and body shape.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RULES_DIR = REPO_ROOT / "rules"


def _extract_frontmatter(text: str) -> tuple[str | None, str]:
    if not text.startswith("---"):
        return None, text
    end = text.find("\n---", 3)
    if end == -1:
        return None, text
    fm = text[3:end].lstrip("\n")
    body = text[end + 4 :].lstrip("\n")
    return fm, body


def _parse_description(fm: str) -> str | None:
    lines = fm.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("description:")), None)
    if start is None:
        return None

    suffix = lines[start][len("description:") :].strip()

    def next_key_index(from_idx: int) -> int:
        for j in range(from_idx, len(lines)):
            if re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*:\s", lines[j]):
                return j
        return len(lines)

    end = next_key_index(start + 1)

    if suffix.startswith(">") or suffix.startswith("|"):
        block = [suffix.lstrip(">|").strip()] if suffix.lstrip(">|").strip() else []
        block.extend(line.strip() for line in lines[start + 1 : end])
        text = " ".join(part for part in block if part)
        return text or None

    if suffix:
        return suffix.strip("'\"")

    block: list[str] = []
    for line in lines[start + 1 : end]:
        if line.startswith("  ") or line.startswith("\t"):
            block.append(line.strip())
            continue
        return None

    text = " ".join(block)
    return text or None


def _description_non_empty(fm: str) -> bool:
    text = _parse_description(fm)
    return text is not None and len(text) >= 10


def _always_apply_value(fm: str) -> bool | None:
    m = re.search(r"^alwaysApply:\s*(true|false)\s*$", fm, re.MULTILINE | re.IGNORECASE)
    if not m:
        return None
    return m.group(1).lower() == "true"


def validate_rule_file(rule_path: Path) -> list[str]:
    errors: list[str] = []
    name = rule_path.name

    if not name.endswith(".mdc"):
        errors.append(f"{name}: rules must use the .mdc extension")
        return errors

    text = rule_path.read_text(encoding="utf-8")
    fm, body = _extract_frontmatter(text)
    if fm is None:
        errors.append(f"{name}: must start with YAML frontmatter (--- ... ---)")
        return errors

    if not _description_non_empty(fm):
        errors.append(f"{name}: frontmatter must include a non-empty `description:`")
    if _always_apply_value(fm) is None:
        errors.append(f"{name}: frontmatter must include `alwaysApply: true` or `alwaysApply: false`")
    if body is None or not body.strip():
        errors.append(f"{name}: body must not be empty after the frontmatter")

    return errors


def main() -> int:
    if not RULES_DIR.is_dir():
        print(f"ok: no {RULES_DIR} directory", file=sys.stderr)
        return 0
    all_errors: list[str] = []
    for child in sorted(RULES_DIR.iterdir()):
        if not child.is_file() or child.name.startswith("."):
            continue
        all_errors.extend(validate_rule_file(child))
    if all_errors:
        print("Rule layout validation failed:\n", file=sys.stderr)
        for e in all_errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("ok: all rule files under rules/ match the required layout", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
