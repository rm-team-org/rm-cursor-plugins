# rm-cursor-plugins

The **Cursor plugin/skill marketplace for RazorMetrics** — a curated collection of
plugins approved for use across the team.

Cursor indexes this repository directly from Git via the marketplace manifest at
[`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json). No build or
runtime is required to consume the marketplace; Cursor reads the manifest and each
plugin's manifest straight from the repo.

## Repository layout

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

## Available plugins

[`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json) is what
Cursor actually reads. [`docs/REGISTRY.md`](docs/REGISTRY.md) is the
human-readable version, listing each plugin's MCP servers, skill counts, and
scope. **Both are generated — never hand-edit them.**

## Adding this marketplace to Cursor

Dashboard → Plugins → **Add Marketplace** → *Import from Repo*, then point it at this
repository. See the [Cursor plugins docs](https://cursor.com/docs/plugins) for details.

## Adding or updating a plugin

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

## Imported sources

### agent-toolkit-for-aws

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

### atlassian

The `atlassian` plugin is vendored from
[atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)
into [`plugins/atlassian/`](plugins/atlassian/). It bundles the official Atlassian
Rovo MCP server (`https://mcp.atlassian.com/v2/mcp`, OAuth — each user signs in on
first use) plus skills for Jira and Confluence workflows. No secrets are stored in
the repo.

## Optional: the vendored AWS toolchain

The marketplace itself needs no toolchain — `generate_marketplace.py` is
stdlib-only Python. `vendor/agent-toolkit-for-aws/` additionally ships its
own contributor validation (manifest/spec conformance, markdown lint, secret
scan) managed with [mise](https://mise.jdx.dev/) and defined in
[`vendor/agent-toolkit-for-aws/mise.toml`](vendor/agent-toolkit-for-aws/mise.toml).
Subject to the known limitation above, this can still be useful for
inspecting the vendored AWS content itself:

```bash
./.cursor/install.sh
cd vendor/agent-toolkit-for-aws
mise run build   # lint + secret scan (plugin/skill validation is a no-op here — see limitation above)
```
