# Plugin Registry

Operational index of every plugin served by this marketplace. Source of truth
for availability is [`.cursor-plugin/marketplace.json`](../.cursor-plugin/marketplace.json);
this file exists for humans and agents to see each plugin's scope, tools, and
storage location without opening every manifest.

Update this table whenever a plugin or MCP server is added, removed, or moved.

| Plugin | Source path | MCP server(s) | Skills | Scope |
| --- | --- | --- | --- | --- |
| `aws-core` | [`plugins/aws/aws-core`](../plugins/aws/aws-core) | `aws-mcp` | 24 | IaC (CDK, CloudFormation), core compute/serverless services, databases, observability, messaging/streaming, AWS SDKs, cost optimization. |
| `aws-agents` | [`plugins/aws/aws-agents`](../plugins/aws/aws-agents) | `awsknowledge` | 8 | Building and operating AI agents on Bedrock AgentCore (Strands, LangGraph), Gateway/MCP tooling, multi-agent orchestration, memory, evaluation, observability. |
| `aws-data-analytics` | [`plugins/aws/aws-data-analytics`](../plugins/aws/aws-data-analytics) | `aws-mcp` | 9 | Data lake/ETL workflows (S3 Tables, Glue, Athena) and vector storage/semantic search on S3 Vectors. |
| `aws-agents-for-devsecops` | [`plugins/aws/aws-agents-for-devsecops`](../plugins/aws/aws-agents-for-devsecops) | `aws-devops-agent` | 13 | Incident investigation, release-readiness review, vulnerability scanning, and penetration testing via the AWS DevOps and Security Agents. |
| `atlassian` | [`plugins/atlassian`](../plugins/atlassian) | `atlassian` | 6 (+ `v1` legacy copies) | Jira/Confluence workflows via the official Rovo MCP server: triage, backlog generation, sprint dashboards, status reports, meeting-note task capture. |

## Layout conventions

- Every plugin sits exactly one level deep under `plugins/`, or under a shared
  ecosystem folder within `plugins/` when there is more than one plugin for
  that ecosystem (e.g. `plugins/aws/<plugin>` for the four AWS plugins).
  Single-plugin ecosystems (e.g. `atlassian`) sit directly under `plugins/`.
- Each plugin keeps its own prompt/instruction content in a local `skills/`
  subdirectory — never loose at the plugin root.
- `agent-toolkit-for-aws/` retains only the vendored upstream project's
  non-plugin scaffolding (canonical skill sources under `skills/`,
  contributor tooling under `tools/`, rules, docs). See the note in the root
  [`README.md`](../README.md) about that tooling's current limitations after
  the AWS plugins were flattened out of that tree.
