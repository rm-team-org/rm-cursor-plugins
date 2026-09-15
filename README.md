# rm-cursor-plugins

The **Cursor plugin/skill marketplace for RazorMetrics** — a curated collection of
AI tools (plugins, skills, and MCP servers) that RazorMetrics has reviewed and
approved for use in Cursor.

## What's in here, in plain terms

- **Plugin** — a bundle of AI tools built around one product or workflow (for
  example, everything for working with AWS, or everything for working with
  Jira/Confluence). Installing a plugin gives you everything in its bundle at
  once.
- **Skill** — a set of instructions that teaches Cursor's AI how to do one
  specific task well (for example, "write a Jira sprint status report").
  Skills come bundled inside plugins.
- **MCP server** — a connection that lets Cursor's AI actually reach an
  outside system (AWS, Jira, Confluence, etc.) to look things up or make
  changes, rather than just talking about it. Also bundled inside plugins.

Under normal use you install a whole plugin, not its pieces separately — a
plugin install gives you its skills and MCP server together. The manual steps
further down exist for the rare case where you need just one piece before a
plugin is available through the marketplace.

## Option 1 (recommended): install through Cursor's plugin browser

This is the easy way, and it's what almost everyone should use.

**One-time setup — an IT admin does this once for the whole company:** an
admin connects this GitHub repository to Cursor as a "Team Marketplace":
Cursor Dashboard → Plugins → Team Marketplaces → **Add Marketplace** →
**Import from Repo**, pointing at this repository. Once that's done, every
approved plugin here becomes available to everyone in Cursor — no one else
needs to repeat this step. *(If Cursor reports "no plugins found" when
importing directly from the URL, that's a known quirk — clone this repo
locally first and import it from the local folder instead.)*

**Once it's connected, to install a plugin yourself:**

1. Open Cursor.
2. Go to **Dashboard → Plugins** (some Cursor versions show this under
   **Settings → Plugins** instead).
3. Find the plugin you want in the RazorMetrics marketplace list — see
   [`docs/REGISTRY.md`](docs/REGISTRY.md) for the full list with a
   plain-language description of what each one does.
4. Click **Install**.

Some plugins may already be turned on for you automatically (an admin can
mark a plugin "Default On" or "Required") — check the list before assuming
you need to install something yourself.

## Option 2: I need one specific tool right now, without waiting on IT

Use this only if the Team Marketplace above isn't connected yet, or you need
just one piece immediately. It's more hands-on than Option 1 — if you get
stuck, use Option 1 instead as soon as it's available.

### Installing just an MCP server (a connection to an outside tool)

1. In this repo, open the plugin's folder under `plugins/` and find its MCP
   config — check the plugin's own `plugin.json` for an `"mcpServers"` field
   to see which filename it uses (usually `.mcp.json` or `mcp.json`). For
   example, the Atlassian plugin's is
   [`plugins/atlassian/.mcp.json`](plugins/atlassian/.mcp.json).
2. Copy everything inside that file's `"mcpServers": { ... }` block.
3. In Cursor, open **Settings → Features → MCP** and click **+ Add New MCP
   Server** — or open the file `~/.cursor/mcp.json` directly (create it if it
   doesn't exist yet) and paste your copied block inside its own
   `"mcpServers": { ... }` object. Use a `.cursor/mcp.json` file inside one
   specific project folder instead if you only want it there.
4. Save, then restart Cursor (or reload the window) if it doesn't appear
   right away.

### Installing just a skill

1. Find the skill's folder inside a plugin's `skills/` folder — for example,
   [`plugins/atlassian/skills/triage-issue`](plugins/atlassian/skills/triage-issue).
2. Copy that whole folder into `~/.cursor/skills/` on your computer.
3. Reload Cursor. If the skill doesn't show up, use Option 1 (the
   marketplace) instead — that's the fully supported path.

### Installing a whole plugin locally (skills + MCP server together)

This needs one setting turned on by an admin first: **Dashboard → Settings →
Security & Identity → Marketplace and Plugins → Allow Local Plugin Imports**.
Once that's on:

1. Copy (or symlink) the plugin's folder — e.g. `plugins/atlassian/` — into
   `~/.cursor/plugins/local/` on your computer, keeping the same folder name.
2. Reload the Cursor window. Cursor should list it as an installed plugin.

## Questions or something not working?

Cursor's own documentation is at
[cursor.com/docs/plugins](https://cursor.com/docs/plugins) and
[cursor.com/docs/context/mcp](https://cursor.com/docs/context/mcp). Cursor's
UI changes fairly often, so if a menu name above doesn't match what you see,
that's the current source of truth. Otherwise, contact whoever manages this
repository for your team.

---

## For repository maintainers

Cursor indexes this repository directly from Git via the marketplace manifest at
[`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json). No build or
runtime is required to consume the marketplace; Cursor reads the manifest and each
plugin's manifest straight from the repo.

### Repository layout

```
plugins/                  # everything Cursor can install lives here, and only here
├── aws/                  # ecosystem folder: more than one plugin from one vendor
│   ├── aws-core/
│   ├── aws-agents/
│   ├── aws-data-analytics/
│   └── aws-agents-for-devsecops/
├── atlassian/             # single-plugin vendor: flat, no wrapper folder
└── razormetrics/          # reserved for RazorMetrics-authored plugins (see its README)
vendor/                   # upstream projects' non-plugin scaffolding (never plugins/)
└── agent-toolkit-for-aws/
tools/
└── generate_marketplace.py   # generates marketplace.json + REGISTRY.md — see below
```

Every plugin sits exactly one level deep under `plugins/`, or one level under
a shared ecosystem folder within `plugins/` when a vendor ships more than one
plugin. Nothing that isn't an installable plugin belongs under `plugins/` —
vendored skill libraries, contributor tooling, and upstream docs live under
`vendor/<name>/` instead.

### Available plugins

[`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json) is what
Cursor actually reads. [`docs/REGISTRY.md`](docs/REGISTRY.md) is the
human-readable version, listing each plugin's MCP servers, skill counts, and
scope. **Both are generated — never hand-edit them.**

### Adding or updating a plugin

1. Add or move the plugin's folder under `plugins/` (or `plugins/<ecosystem>/`
   if it's one of several plugins from the same vendor), with its own
   `plugin.json` at the plugin root.
2. Run `python3 tools/generate_marketplace.py` to regenerate
   `.cursor-plugin/marketplace.json` and `docs/REGISTRY.md` from that
   `plugin.json` (name, description) plus the plugin's `mcp.json`/`.mcp.json`
   and `skills/` folder.
3. Commit the plugin and the regenerated files together.

CI runs `python3 tools/generate_marketplace.py --check` on every PR
(`.github/workflows/validate-marketplace.yml`) and fails if the generated
files don't match what's on disk, so a plugin move or addition can't leave a
stale marketplace listing behind.

### Imported sources

#### agent-toolkit-for-aws

The AWS plugins are vendored from
[aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws) and
flattened to [`plugins/aws/`](plugins/aws/) so every plugin sits one level
deep under `plugins/`, matching the other plugins in this marketplace.
[`vendor/agent-toolkit-for-aws/`](vendor/agent-toolkit-for-aws/) holds the
upstream project's non-plugin scaffolding: canonical skill sources, docs,
rules, and contributor tooling.

**Known limitation:** the toolkit's own `tools/validate.py`,
`tools/validate_spec.py`, and `tools/sync-plugin-skills.py` (run via
`mise run build` in that directory) resolve `plugins/` relative to
`vendor/agent-toolkit-for-aws/` itself, so they find no plugins to check now
that the AWS plugins live at [`plugins/aws/`](plugins/aws/) instead. This is
unmodified vendored upstream code; re-pointing it at the new location would
diverge from upstream and was left out of scope. `generate_marketplace.py`
above is this repo's own replacement for the piece of that tooling that
matters here — keeping the marketplace listing in sync with `plugins/`.

#### atlassian

The `atlassian` plugin is vendored from
[atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)
into [`plugins/atlassian/`](plugins/atlassian/). It bundles the official Atlassian
Rovo MCP server (`https://mcp.atlassian.com/v2/mcp`, OAuth — each user signs in on
first use) plus skills for Jira and Confluence workflows. No secrets are stored in
the repo.

#### rm_cursor_skills (RazorMetrics internal)

The `razormetrics-core` plugin
([`plugins/razormetrics/razormetrics-core/`](plugins/razormetrics/razormetrics-core/))
is authored in-house and vendored from
[rm_porcupine/rm_cursor_skills](https://bitbucket.org/rm_porcupine/rm_cursor_skills).
It bundles internal skills (CloudWatch/Jira ALR alarm triage, Liquibase synthetic
dataset authoring and validation) and shared agent rules (requirements
clarification, response formatting). The upstream project's non-plugin
scaffolding — contributor scripts, the `rm-link-cursor.sh` local installer, and
CI config — lives under
[`vendor/rm_cursor_skills/`](vendor/rm_cursor_skills/).

### Optional: the vendored AWS toolchain

The marketplace itself needs no toolchain — `generate_marketplace.py` is
stdlib-only Python, so the default environment (which already has Python 3.12)
is enough to validate the listing.

`vendor/agent-toolkit-for-aws/` additionally ships the upstream project's own
contributor validation (manifest/spec conformance, markdown lint, secret scan)
managed with [mise](https://mise.jdx.dev/) and defined in
[`vendor/agent-toolkit-for-aws/mise.toml`](vendor/agent-toolkit-for-aws/mise.toml).
It is not needed to build or serve this marketplace. If you want to inspect the
vendored AWS content with its own tooling, install `mise` yourself and run it in
that directory (subject to the known limitation above):

```bash
cd vendor/agent-toolkit-for-aws
mise run build   # lint + secret scan (plugin/skill validation is a no-op here — see limitation above)
```
