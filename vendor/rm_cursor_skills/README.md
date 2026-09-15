# rm_cursor_skills

Shared **Cursor Agent Skills** and **User Rules** for Razor Metrics: one place to author them and reuse them everywhere Cursor runs.

## Adding a skill

For each skill, add a folder under `skills/<skill-name>/` with:

| File        | Role                                                                    |
| ----------- | ----------------------------------------------------------------------- |
| `SKILL.md`  | Instructions for the agent (when to use it, steps, constraints).        |
| `README.md` | Short human-oriented summary: what it does, optional examples or links. |

Example layout: `skills/cloudwatch-alarm-logs-insights/SKILL.md` and `skills/cloudwatch-alarm-logs-insights/README.md`.

## Adding a rule

Add a `.mdc` file under `rules/` with YAML frontmatter:

| Field         | Role                                                                 |
| ------------- | -------------------------------------------------------------------- |
| `description` | Short summary (shown in the rule picker).                            |
| `alwaysApply` | Creator's choice: `true` for every session, `false` to scope by file. |
| `globs`       | Optional file patterns when `alwaysApply` is `false`.                |

Set `alwaysApply` and `globs` however fits the rule — there is no repo-wide default. Linking is per file, so only teammates who symlink a rule get it; others are unaffected regardless of its frontmatter.

Example: `rules/requirements-analysis.mdc`, `rules/response-formatting.mdc`.

## Linking skills and rules locally

1. Clone this repository to your local machine.

2. Run the helper script from this repository (it finds `./skills` and `./rules` next to the script):

```bash
./rm-link-cursor.sh
```

To remove symlinks that point at this repo:

```bash
./rm-link-cursor.sh -u
```

The script:

- Creates `~/.cursor/skills` and `~/.cursor/rules` as normal directories if they do not exist (link mode only).
- Walks each skill folder and each `.mdc` rule, asking whether to link or unlink it.
- For each item, you can answer **y** (yes), **n** (skip this one), **a** (yes for this and all remaining in the current section), or **s** (skip this and all remaining in the current section).

Each linked item is its own symlink, so you can install only the skills and rules you want while keeping others out of your Cursor config.

If you previously linked the whole `skills` or `rules` folder with an older setup, `~/.cursor/skills` or `~/.cursor/rules` may be a single symlink. Remove that symlink first, then run the script again.

⚠️ If Cursor doesn't immediately detect the skills or rules, press `Cmd+Shift+P`, then search for and run **Developer: Reload window**.
