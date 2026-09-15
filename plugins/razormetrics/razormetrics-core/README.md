# razormetrics-core

RazorMetrics-authored Cursor plugin bundling internal skills and shared agent
rules. Vendored from
[rm_porcupine/rm_cursor_skills](https://bitbucket.org/rm_porcupine/rm_cursor_skills);
the upstream project's contributor tooling and scripts live under
[`vendor/rm_cursor_skills/`](../../../vendor/rm_cursor_skills/).

## Skills

- `cloudwatch-alarm-logs-insights` — build CloudWatch Logs Insights console URLs around an ALR alarm time.
- `jira-alr-alarm-triage-router` — route mixed ALR alarm tickets to the correct triage skill.
- `jira-alr-auth-error-triage` — triage RDS DB authentication ALR tickets in Jira.
- `jira-alr-aws-notification-triage` — triage "AWS Notification Message" ALR tickets (GuardDuty/runtime).
- `liquibase-synthetic-dataset-authoring` — author isolated synthetic datasets for Liquibase.
- `liquibase-synthetic-scenario-validation` — restore and validate Liquibase synthetic scenarios.

## Rules

- `requirements-analysis.mdc` — clarify ambiguous requests before implementing.
- `response-formatting.mdc` — keep responses concise and shaped to the task type.
