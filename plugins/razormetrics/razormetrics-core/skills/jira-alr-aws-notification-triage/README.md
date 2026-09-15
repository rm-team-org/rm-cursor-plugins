# jira-alr-aws-notification-triage

Triages **AWS Notification Message** ALR tickets in Jira: classifies GuardDuty and runtime alarms from the issue description, applies known false-positive or noise rules (comment + **Done**, or **Canceled**), and returns a summary table with Chrome bulk-open snippets.

**Skill file:** [SKILL.md](./SKILL.md)

## What it does

For each ticket whose **summary** is `AWS Notification Message`:

1. Fetches the issue via **Atlassian MCP** (`summary`, `description`, `assignee`, sprint).
2. Skips mutations when there is **no assignee** (reported in the summary).
3. Matches the description to a known alarm pattern (see below).
4. **Canceled** — short ECS runtime noise (unidentified task / agent not reporting).
5. **Done** — posts the standard false-positive comment, then transitions (SentinelOne PTRACE, Cybermaxx volume scan, Cybermaxx portscan, Cybermaxx SSH brute force, Kafka credential exfiltration).
6. Returns a **triage summary table** (alarm type, action, final status, flags such as `NO SPRINT` or `NEEDS REVIEW`).
7. Appends a **`const urls = [...]`** JavaScript block to open all tickets in Chrome at once.

Tickets that do not match any rule are left unchanged and flagged **NEEDS REVIEW**.

## Alarm types handled

| Pattern in description | Result | Reference |
| ---------------------- | ------ | --------- |
| `Unidentified issue, for task(s) in TaskDefinition` (short payload) | Canceled | [ALR-15118](https://razormetrics.atlassian.net/browse/ALR-15118) |
| `Agent not reporting, for task(s) in TaskDefinition` (short payload) | Canceled | [ALR-16433](https://razormetrics.atlassian.net/browse/ALR-16433) |
| `Process injection via PTRACE was detected in a resource` | Comment + Done | [ALR-15552](https://razormetrics.atlassian.net/browse/ALR-15552) |
| `security risk(s) detected including` | Comment + Done | [ALR-13721](https://razormetrics.atlassian.net/browse/ALR-13721) |
| Kafka `rm_kafka_kafbat_prod_instance_profile_role` credential exfiltration | Comment + Done (API name from `"api":"…"` in JSON) | [ALR-15276](https://razormetrics.atlassian.net/browse/ALR-15276) |
| `An outbound portscan was detected from EC2 instance` + authorized scanner instance ID | Comment + Done | [ALR-14946](https://razormetrics.atlassian.net/browse/ALR-14946) |

| `Brute force attacks are used to gain unauthorized access to your instance by guessing the SSH password` + authorized scanner source IP | Comment + Done | [ALR-13722](https://razormetrics.atlassian.net/browse/ALR-13722) |

**Authorized Cybermaxx portscan instance IDs:** `i-07e6506c4f6086512`, `i-0d03eca37ce960f15`, `i-0b9cdba03999a3bbd`, `i-03381c0ae1bcf2e9e`, `i-02f5f05daa6b71b20`. Portscan text with an instance ID **not** on this list → **NEEDS REVIEW**.

**Authorized Cybermaxx SSH brute-force source IPs:** `172.71.10.104`, `172.40.3.195`, `172.61.13.233`, `172.41.14.64`, `172.22.13.101`, `172.61.59.82`. SSH brute-force text with a source IP **not** on this list → **NEEDS REVIEW**.

**Short** (first two rows in the table only): description under 2500 characters and `detail-type` is `GuardDuty Runtime Protection Unhealthy`.

## When to use

- Batch-triaging open **AWS Notification Message** alerts in ALR.
- Closing recurring GuardDuty false positives (SentinelOne, Cybermaxx scanner, outbound portscan, SSH brute force, VPC 172.61.x.x / Kafka).
- Canceling ECS GuardDuty runtime protection noise without manual investigation.

Provide ticket keys, browse URLs, or JQL—for example:

```text
project = ALR AND summary = "AWS Notification Message" AND status = Backlog
```

## Requirements

- **Atlassian MCP** connected (`plugin-atlassian-atlassian` or `user-Atlassian`).
- Tickets should have an **assignee** before triage (unassigned tickets are reported only, not updated).
- Issues already **Done**, **Canceled**, or **Duplicate** are skipped unless you ask to re-run.

## Related skills

- **`jira-alr-auth-error-triage`** — RDS DB authentication alarms (assign + CloudWatch Logs Insights comment).
- **`cloudwatch-alarm-logs-insights`** — build Logs Insights URLs from alarm `Time:` lines.
