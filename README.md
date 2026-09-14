# rm-cursor-plugins

The **Cursor plugin/skill marketplace for RazorMetrics** — a curated collection of
plugins approved for use across the team.

Cursor indexes this repository directly from Git via the marketplace manifest at
[`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json). No build or
runtime is required to consume the marketplace; Cursor reads the manifest and each
plugin's manifest straight from the repo.

## Available plugins

Defined in [`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json); see
[`docs/REGISTRY.md`](docs/REGISTRY.md) for each plugin's MCP servers, skill
counts, and operational scope.

| Plugin | Source |
| --- | --- |
| `aws-core` | [`plugins/aws/aws-core`](plugins/aws/aws-core) |
| `aws-agents` | [`plugins/aws/aws-agents`](plugins/aws/aws-agents) |
| `aws-data-analytics` | [`plugins/aws/aws-data-analytics`](plugins/aws/aws-data-analytics) |
| `aws-agents-for-devsecops` | [`plugins/aws/aws-agents-for-devsecops`](plugins/aws/aws-agents-for-devsecops) |
| `atlassian` | [`plugins/atlassian`](plugins/atlassian) |

## Adding this marketplace to Cursor

Dashboard → Plugins → **Add Marketplace** → *Import from Repo*, then point it at this
repository. See the [Cursor plugins docs](https://cursor.com/docs/plugins) for details.

## Imported sources

### agent-toolkit-for-aws

The AWS plugins above are vendored from
[aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws) and
flattened to [`plugins/aws/`](plugins/aws/) so every plugin sits one level
deep under `plugins/`, matching the other plugins in this marketplace.
[`agent-toolkit-for-aws/`](agent-toolkit-for-aws/) itself still holds the
upstream project's non-plugin scaffolding: canonical skill sources, docs,
rules, and contributor tooling.

### atlassian

The `atlassian` plugin is vendored from
[atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)
into [`plugins/atlassian/`](plugins/atlassian/). It bundles the official Atlassian
Rovo MCP server (`https://mcp.atlassian.com/v2/mcp`, OAuth — each user signs in on
first use) plus skills for Jira and Confluence workflows. No secrets are stored in
the repo.

## Optional: validating plugins before publishing

The marketplace itself needs no toolchain. The imported toolkit ships its own
contributor validation (manifest/spec conformance, markdown lint, secret scan),
managed with [mise](https://mise.jdx.dev/) and defined in
[`agent-toolkit-for-aws/mise.toml`](agent-toolkit-for-aws/mise.toml). This is useful
in CI to check plugin changes before they are approved, but is **not** required to
serve the marketplace.

**Known limitation:** the toolkit's own `tools/validate.py`,
`tools/validate_spec.py`, and `tools/sync-plugin-skills.py` resolve `plugins/`
relative to `agent-toolkit-for-aws/` itself, so `mise run build`/`validate`
will find no plugins to check now that the AWS plugins live at
[`plugins/aws/`](plugins/aws/) instead. This is unmodified vendored upstream
code; re-pointing it at the new location would diverge from upstream and was
left out of scope for this restructuring. None of `agent-toolkit-for-aws/`'s
own `.github/workflows/` run in this repo either way — GitHub Actions only
reads workflows from the repository-root `.github/workflows/`, not a nested
one.

```bash
./.cursor/install.sh
cd agent-toolkit-for-aws
mise run build   # lint + validate + security scan (see limitation above)
```
