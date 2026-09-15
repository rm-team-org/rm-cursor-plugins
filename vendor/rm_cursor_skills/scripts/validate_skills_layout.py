#!/usr/bin/env python3
"""
Validate skills/ layout per repo README and reference skill
(cloudwatch-alarm-logs-insights): SKILL.md frontmatter + README structure.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"


def _extract_frontmatter(text: str) -> tuple[str | None, str]:
    if not text.startswith("---"):
        return None, text
    end = text.find("\n---", 3)
    if end == -1:
        return None, text
    fm = text[3:end].lstrip("\n")
    body = text[end + 4 :].lstrip("\n")
    return fm, body


def _name_from_frontmatter(fm: str) -> str | None:
    m = re.search(r"^name:\s*(\S+)\s*$", fm, re.MULTILINE)
    return m.group(1).strip("'\"") if m else None


def _description_non_empty(fm: str) -> bool:
    if "description:" not in fm:
        return False
    # Block after "description:" (folded / literal / or same-line) through end of frontmatter
    i = fm.index("description:")
    rest = fm[i + len("description:") :]
    rest = re.sub(r"^\s*>\s*|-\s*\n", "\n", rest, count=1)
    rest = re.sub(r"^\s*>\-?\s*\n?", "", rest)
    # Drop optional first-line YAML indicator
    lines = rest.splitlines()
    body: list[str] = []
    for line in lines:
        if re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*:\s", line):
            break
        body.append(line)
    joined = "\n".join(body).strip()
    if not joined:
        # Same-line description: "description: some text"
        one = rest.strip()
        if one and not one.startswith(">"):
            return len(one) > 0
        return False
    return len(joined) >= 10


def _readme_h1(text: str) -> str | None:
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("# ") and not s.startswith("## "):
            return s[2:].strip()
    return None


def validate_skill_dir(skill_dir: Path) -> list[str]:
    errors: list[str] = []
    name = skill_dir.name
    if name.startswith(".") or not skill_dir.is_dir():
        return errors

    skill_md = skill_dir / "SKILL.md"
    readme_md = skill_dir / "README.md"

    if not skill_md.is_file():
        errors.append(f"{name}: missing SKILL.md")
        return errors
    if not readme_md.is_file():
        errors.append(f"{name}: missing README.md")
        return errors

    st = skill_md.read_text(encoding="utf-8")
    fm, body = _extract_frontmatter(st)
    if fm is None:
        errors.append(f"{name}: SKILL.md must start with YAML frontmatter (--- ... ---)")
    else:
        n = _name_from_frontmatter(fm)
        if not n:
            errors.append(f"{name}: SKILL.md frontmatter must include a `name:` field")
        elif n != name:
            errors.append(
                f"{name}: SKILL.md frontmatter `name:` ({n!r}) must match folder name ({name!r})"
            )
        if not _description_non_empty(fm):
            errors.append(
                f"{name}: SKILL.md frontmatter must include a non-empty `description:`"
            )
    if body is not None and not re.search(r"^# .+", body, re.MULTILINE):
        errors.append(
            f"{name}: SKILL.md must contain a markdown H1 title (`# ...`) after the frontmatter"
        )

    rt = readme_md.read_text(encoding="utf-8")
    h1 = _readme_h1(rt)
    if h1 is None:
        errors.append(f"{name}: README.md must start with an H1 line (`# <title>`)")
    elif h1 != name:
        errors.append(
            f"{name}: README.md H1 must be `# {name}` (found `# {h1}`; align with reference layout)"
        )
    if "## What it does" not in rt:
        errors.append(f"{name}: README.md must include section `## What it does`")
    if "## When to use" not in rt:
        errors.append(f"{name}: README.md must include section `## When to use`")

    return errors


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f"ok: no {SKILLS_DIR} directory", file=sys.stderr)
        return 0
    all_errors: list[str] = []
    for child in sorted(SKILLS_DIR.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        all_errors.extend(validate_skill_dir(child))
    if all_errors:
        print("Skill layout validation failed:\n", file=sys.stderr)
        for e in all_errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("ok: all skill folders under skills/ match the required layout", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
