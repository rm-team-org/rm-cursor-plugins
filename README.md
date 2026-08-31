# rm-cursor-plugins

The **Cursor plugin/skill marketplace for RazorMetrics** — a curated collection of
plugins approved for use across the team.

Cursor indexes this repository directly from Git via the marketplace manifest at
[`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json). No build or
runtime is required to consume the marketplace; Cursor reads the manifest and each
plugin's manifest straight from the repo.

## Available plugins

Defined in [`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json):

| Plugin | Source |
| --- | --- |
| `aws-core` | [`agent-toolkit-for-aws/plugins/aws-core`](agent-toolkit-for-aws/plugins/aws-core) |
| `aws-agents` | [`agent-toolkit-for-aws/plugins/aws-agents`](agent-toolkit-for-aws/plugins/aws-agents) |
| `aws-data-analytics` | [`agent-toolkit-for-aws/plugins/aws-data-analytics`](agent-toolkit-for-aws/plugins/aws-data-analytics) |
| `aws-agents-for-devsecops` | [`agent-toolkit-for-aws/plugins/aws-agents-for-devsecops`](agent-toolkit-for-aws/plugins/aws-agents-for-devsecops) |

## Adding this marketplace to Cursor

Dashboard → Plugins → **Add Marketplace** → *Import from Repo*, then point it at this
repository. See the [Cursor plugins docs](https://cursor.com/docs/plugins) for details.

## Imported sources

### agent-toolkit-for-aws

The AWS plugins above are vendored from
[aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws) into
[`agent-toolkit-for-aws/`](agent-toolkit-for-aws/).

## Optional: validating plugins before publishing

The marketplace itself needs no toolchain. The imported toolkit ships its own
contributor validation (manifest/spec conformance, markdown lint, secret scan),
managed with [mise](https://mise.jdx.dev/) and defined in
[`agent-toolkit-for-aws/mise.toml`](agent-toolkit-for-aws/mise.toml). This is useful
in CI to check plugin changes before they are approved, but is **not** required to
serve the marketplace.

To run it, [`.cursor/install.sh`](.cursor/install.sh) provisions the toolchain
(also wired into [`.cursor/environment.json`](.cursor/environment.json) for Cloud
Agents):

```bash
./.cursor/install.sh
cd agent-toolkit-for-aws
mise run build   # lint + validate + security scan
```
