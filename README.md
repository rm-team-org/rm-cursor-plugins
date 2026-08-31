# rm-cursor-plugins

A collection of plugins approved for use with Cursor.

## Imported plugin collections

### agent-toolkit-for-aws

Imported from [aws/agent-toolkit-for-aws](https://github.com/aws/agent-toolkit-for-aws)
into [`agent-toolkit-for-aws/`](agent-toolkit-for-aws/). It provides plugins, skills,
and rules that help AI coding agents build, deploy, and manage applications on AWS
(Cursor, Claude Code, Codex, and Kiro compatible).

## Development environment

The toolchain is managed with [mise](https://mise.jdx.dev/) and defined in
[`agent-toolkit-for-aws/mise.toml`](agent-toolkit-for-aws/mise.toml)
(Node, Python, uv, gitleaks, and markdownlint-cli2).

Cloud Agents provision the environment automatically via
[`.cursor/environment.json`](.cursor/environment.json), which runs
[`.cursor/install.sh`](.cursor/install.sh). To set up locally:

```bash
./.cursor/install.sh
```

To lint, validate, and run the security scan for the imported toolkit:

```bash
cd agent-toolkit-for-aws
mise run build
```
