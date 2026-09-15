# jira-alr-auth-error-triage

Triages RDS DB authentication ALR tickets in Jira: assigns each issue to the responsible engineer and posts a CloudWatch Logs Insights comment with safe ADF link handling.

**Skill file:** [SKILL.md](./SKILL.md)

## What it does

For each ticket provided:

1. Looks up the assignee's Jira `accountId` by email via the Atlassian MCP.
2. Assigns the Jira issue to that user.
3. Posts a comment using **ADF** (not markdown) so the CloudWatch URL — which contains `*` characters — is not corrupted by Jira's markdown pipeline. The comment contains a clickable "CloudWatch Logs Insights" hyperlink and an auth-attribution line (`Auth errors caused by <IP>, with user <name> for the associated workspace`).
4. Returns a triage summary in chat with clickable ticket links, assignee, and comment confirmation.

## When to use

Use when you have one or more ALR RDS authentication alarm tickets to triage and you can supply, per ticket:

- Jira ticket key (e.g. `ALR-13742`)
- CloudWatch Logs Insights URL for the alarm window
- Source IP address from the logs
- DB username from the logs
- Assignee email address

Input can be provided as free-form text, a pasted table, or a spreadsheet — for example a Google Sheet like [this one](https://docs.google.com/spreadsheets/d/1lswfSusWYHBwx7b1RuHW0YgcpyEKSSJPMKgwWHkdgq8/edit?gid=2049834899#gid=2049834899) with one row per ticket.

If you need to first **build** the Logs Insights URLs from alarm timestamps, use the companion skill **`cloudwatch-alarm-logs-insights`** before running this one.
