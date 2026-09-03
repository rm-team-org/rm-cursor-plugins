# Repo structure & vendoring commands

## Layout

```
rm-cursor-plugins/
├── .cursor-plugin/
│   └── marketplace.json          # root marketplace manifest (name, owner, metadata, plugins[])
├── plugins/                      # first-party / single-plugin vendored additions
│   └── <name>/                   #   e.g. plugins/atlassian
│       ├── plugin.json           #   and/or .cursor-plugin/plugin.json
│       ├── mcp.json / .mcp.json  #   MCP config (endpoint only; no secrets)
│       └── skills/<skill>/SKILL.md
├── <collection-repo>/            # multi-plugin upstream repo, vendored whole
│   └── plugins/<plugin>/         #   e.g. agent-toolkit-for-aws/plugins/aws-core
└── README.md
```

Each `source` in `marketplace.json` is a path **relative to the repo root**. The entry
`name` must equal the plugin manifest's `name`.

## Vendoring commands

`rsync` is not available; use `cp -a` and delete the nested `.git`.

Single plugin repo → `plugins/<name>/`:

```bash
git clone --depth 1 <upstream-url> /tmp/<name>
cp -a /tmp/<name> plugins/<name>
rm -rf plugins/<name>/.git
```

Multi-plugin collection repo → `<repo-name>/`:

```bash
git clone --depth 1 <upstream-url> /tmp/<repo-name>
cp -a /tmp/<repo-name> <repo-name>
rm -rf <repo-name>/.git
# then add one marketplace entry per plugin, e.g. source "<repo-name>/plugins/<plugin>"
```

## Bare MCP server wrapper

When the source is only an MCP endpoint (no plugin manifest), create
`plugins/<name>/` with:

`.cursor-plugin/plugin.json`:

```json
{
  "name": "<name>",
  "description": "<what it connects to>",
  "version": "0.1.0",
  "author": { "name": "<vendor>" },
  "license": "<license>",
  "mcpServers": "./.mcp.json"
}
```

`.mcp.json` (Cursor native vocabulary):

```json
{
  "mcpServers": {
    "<name>": { "type": "http", "url": "https://<vendor-recommended-endpoint>" }
  }
}
```

`mcp.json` (Agent Plugins portable vocabulary, keep endpoint aligned):

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {
    "<name>": { "type": "streamable-http", "url": "https://<vendor-recommended-endpoint>" }
  }
}
```

Use the vendor's current recommended endpoint from official docs. For servers needing
credentials, rely on OAuth or per-user Cursor config — never commit tokens/keys.

## Precedent in this repo

- `agent-toolkit-for-aws/` — multi-plugin collection from `github.com/aws/agent-toolkit-for-aws`
  (Apache-2.0): entries `aws-core`, `aws-agents`, `aws-data-analytics`, `aws-agents-for-devsecops`.
- `plugins/atlassian/` — single dual-format plugin from `github.com/atlassian/atlassian-mcp-server`
  (Apache-2.0): MCP endpoint `https://mcp.atlassian.com/v2/mcp` (OAuth) + skills.
