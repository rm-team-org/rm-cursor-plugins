# jira-alr-alarm-triage-router

Routes a **mixed batch** of ALR alarm tickets to the right triage skill, runs each workflow, and returns **one combined summary** plus Chrome bulk-open snippets.

**Skill file:** [SKILL.md](./SKILL.md)

## What it does

1. Accepts multiple ALR keys, URLs, or JQL results in one request.
2. Fetches all issues via **Atlassian MCP**.
3. **Classifies** each ticket into a bucket:
   - **AWS Notification Message** → [`jira-alr-aws-notification-triage`](../jira-alr-aws-notification-triage/SKILL.md)
   - **RDS DB authentication** → [`cloudwatch-alarm-logs-insights`](../cloudwatch-alarm-logs-insights/SKILL.md) (+ optional [`jira-alr-auth-error-triage`](../jira-alr-auth-error-triage/SKILL.md))
   - **WAF blocked requests** → `cloudwatch-alarm-logs-insights` only
   - **Unknown** → flagged `NEEDS REVIEW`
4. Executes the child skill(s) per ticket.
5. Outputs a **single summary table** (route, action, status, flags).
6. Appends **`ticketUrls`** and **`urls`** JavaScript blocks for Chrome.

## When to use

- You paste **several ALR tickets** and they might be different alarm types.
- You want one command like *“Triage these alarms”* instead of naming each skill.
- You are clearing a Backlog slice that mixes GuardDuty, CloudWatch WAF, and RDS auth alerts.

Optional: include a **table** (or spreadsheet) with IP, DB username, and assignee email for RDS auth rows — otherwise those tickets get Logs Insights URLs only.

## What is automatic vs manual

| Alarm family | From keys alone | Needs extra input |
| ------------ | --------------- | ----------------- |
| AWS Notification Message | Comment + Done/Canceled (if assigned + rule match) | — |
| RDS auth | Logs Insights URL | IP, DB user, assignee email for assign + ADF comment |
| WAF | Logs Insights URL | — |
| Unknown | — | Human triage |

## Related skills

- [`jira-alr-aws-notification-triage`](../jira-alr-aws-notification-triage/README.md) — GuardDuty / ECS false positives and noise
- [`cloudwatch-alarm-logs-insights`](../cloudwatch-alarm-logs-insights/README.md) — WAF and RDS Logs Insights URLs
- [`jira-alr-auth-error-triage`](../jira-alr-auth-error-triage/README.md) — RDS auth assign + comment

## Shared repo

Also maintained under [rm_cursor_skills](https://bitbucket.org/rm_porcupine/rm_cursor_skills) in `skills/jira-alr-alarm-triage-router/`. Link skills and rules with `rm-link-cursor.sh` (see repo [README](https://bitbucket.org/rm_porcupine/rm_cursor_skills/src/master/README.md)).
