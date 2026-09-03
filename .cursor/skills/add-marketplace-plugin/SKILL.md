---
name: add-marketplace-plugin
description: Locate an official, company-published plugin, skill, or MCP server by name and add it to this RazorMetrics Cursor marketplace repo — vendoring the trusted source, registering it in .cursor-plugin/marketplace.json, updating the README, and keeping the repo's file/folder structure correct. Use when the user names a plugin, skill, or MCP server to add to the marketplace (e.g. "add the GitHub MCP server", "add the Atlassian plugin", "add plugin X to our marketplace").
---

# Add a plugin / skill / MCP server to the marketplace

This repo is the **RazorMetrics Cursor plugin/skill marketplace**. Cursor indexes it
straight from Git by reading `.cursor-plugin/marketplace.json` at the repo root; no
build or runtime is involved. This skill adds a new, trusted item to that manifest
while keeping the repo self-contained and structurally correct.

## Inputs to confirm

1. **Name** of the item (e.g. `atlassian`, `github`, `aws-core`).
2. **Type**: plugin, skill, or MCP server (if unclear, discover it in step 2).
3. **Description** (optional): if the user gave exact wording, use it verbatim.

## Workflow

Copy and track this checklist:

```
- [ ] 1. Locate the official, trusted source
- [ ] 2. Determine the item's format
- [ ] 3. Vendor it into the correct location (drop nested .git; no secrets)
- [ ] 4. Register it in .cursor-plugin/marketplace.json
- [ ] 5. Validate (scripts/validate_marketplace.py)
- [ ] 6. Update README.md
- [ ] 7. Branch, commit, push, open PR (merge only when told)
```

### 1. Locate the official, trusted source

Only add sources published by the owning company. **Verify authenticity** — do not
add third-party forks or mirrors:

- Prefer the Cursor Marketplace listing: `https://cursor.com/marketplace/<owner>/<name>`.
- Confirm the canonical GitHub repo is under the vendor's **official org** (e.g.
  `github.com/aws`, `github.com/atlassian`, `github.com/github`) and cross-check it
  from the vendor's official docs.
- Record the upstream repo URL and its **OSI license** (e.g. Apache-2.0, MIT).

If you cannot confirm the source is official, stop and report rather than guess.

### 2. Determine the item's format

Inspect the source repo. Cursor supports two plugin formats plus bare components:

- **Agent Plugin** — root `plugin.json` (schema `agent-plugins.org/...`). Packages
  skills and MCP servers.
- **Cursor Plugin** — `.cursor-plugin/plugin.json`. Adds rules, agents, commands,
  hooks, variables. Many official plugins ship **both** manifests (dual-format).
- **Bare MCP server** — only an MCP endpoint/config, no plugin manifest.
- **Bare skill(s)** — `SKILL.md` file(s) with no plugin manifest.

Note the plugin's manifest `name` — the marketplace entry name must match it exactly.

### 3. Vendor into the correct location

Vendor a self-contained copy (this matches how `agent-toolkit-for-aws/` and
`plugins/atlassian/` were added) and **always remove the nested `.git`**. Choose the
location by shape (see [reference/structure.md](reference/structure.md) for the full
map and commands):

- **Single official plugin repo** (the repo root *is* one plugin) → `plugins/<name>/`.
- **Multi-plugin collection repo** → vendor the whole repo into `<repo-name>/` at the
  repo root, then add one entry per plugin pointing at `<repo-name>/.../<plugin>`.
- **Bare MCP server** → create a Cursor-plugin wrapper `plugins/<name>/` with a
  `.cursor-plugin/plugin.json` and `mcp.json` + `.mcp.json` holding the vendor's
  current recommended endpoint. Use OAuth or user-supplied config — **never commit
  secrets** (tokens, keys, passwords).
- **Bare skill** → `plugins/<name>/` with `.cursor-plugin/plugin.json` and
  `skills/<skill-name>/SKILL.md`, or add the skill under an existing plugin's `skills/`.

### 4. Register it in the marketplace manifest

Add an entry to `plugins` in `.cursor-plugin/marketplace.json`. A plugin entry accepts
**only** these keys (`additionalProperties: false`):

- `name` (required) — kebab-case, must equal the plugin's manifest `name`.
- `source` (required) — path to the plugin dir relative to the repo root.
- `description` (optional).
- `minClientVersions` (optional) — e.g. `{ "cursor": "3.13.0" }`.

Put `keywords`, `category`, `tags`, `version`, etc. in the plugin's own `plugin.json`,
**not** in the marketplace entry (they fail validation here).

### 5. Validate

Run the bundled validator (pure stdlib, no deps). It checks the schema rules and that
every `source` resolves to a plugin whose manifest `name` matches:

```bash
python3 .cursor/skills/add-marketplace-plugin/scripts/validate_marketplace.py
```

Fix any reported problem before continuing. Also confirm the new plugin dir contains a
manifest plus its components (`skills/`, `mcp.json`/`.mcp.json`).

### 6. Update README.md

- Add a row to the **Available plugins** table (`<name>` → linked source path).
- Add a short **Vendored sources** subsection noting the upstream repo, its license,
  and — for MCP — the endpoint and that auth is OAuth/user-config with no stored secrets.

### 7. Branch, commit, push, open PR

- Create a branch: `git checkout -b cursor/add-<name>-<suffix>` (match this repo's
  existing branch naming; keep names lowercase).
- Commit the vendored files, the manifest change, and the README update together.
- Push and open a PR with `ManagePullRequest`; base `main`.
- **Do not merge unless the user explicitly says to.** After merge, remind the user to
  click **Refresh** in Dashboard → Plugins so the marketplace re-reads the manifest.

## Notes

- Keep the repo self-contained: vendored copies mean updates are manual — re-vendor to
  update a plugin later.
- Never weaken security to make something work; never commit credentials.
- If the item is already present, update it in place rather than duplicating the entry.
