---
name: jira-alr-alarm-triage-router
description: >-
  Routes mixed ALR alarm tickets to the correct triage skill: AWS Notification
  Message (GuardDuty), CloudWatch WAF/RDS Logs Insights URLs, or RDS auth assign
  + comment. Use when the user pastes multiple ALR keys or links of different
  alarm types, asks to triage a batch of alarms, or says "route these alerts".
---

# Jira ALR — mixed alarm triage router

Entry point for **batch ALR triage** when tickets may be **different alarm families**. Classify each issue, delegate to the child skill, and return **one combined summary**.

## Inputs

| Input | Example |
| ----- | ------- |
| Ticket key(s) | `ALR-15552`, `ALR-13823`, `ALR-13742` |
| Browse URL(s) | `https://razormetrics.atlassian.net/browse/ALR-15552` |
| JQL (optional) | `project = ALR AND status = Backlog ORDER BY created DESC` |
| Per-ticket metadata (optional) | Table with IP, DB user, assignee email for RDS auth rows |

Deduplicate keys; process in stable key order.

## Child skills (read and follow each when routing)

| Skill | Role |
| ----- | ---- |
| **`jira-alr-aws-notification-triage`** | GuardDuty / ECS runtime — comment + Done/Canceled from description alone |
| **`cloudwatch-alarm-logs-insights`** | WAF / RDS CloudWatch alarms — build Logs Insights URLs (read-only) |
| **`jira-alr-auth-error-triage`** | RDS auth — assign + ADF comment (needs IP, user, email per ticket) |

## Step 1 — Fetch all issues

Use **Atlassian MCP** (`plugin-atlassian-atlassian` or `user-Atlassian`):

1. Resolve `cloudId` (`razormetrics.atlassian.net` or `getAccessibleAtlassianResources`).
2. Batch-fetch with `getJiraIssue` or `searchJiraIssuesUsingJql` (`key in (...)`).
3. Fields: `summary`, `description`, `status`, `assignee`, `customfield_10021` (Sprint).

## Step 2 — Classify each ticket

Use **first match** in this order:

```text
1. AWS Notification Message  → child: jira-alr-aws-notification-triage
2. RDS auth (CloudWatch)     → see Step 3 (logs-insights + optional auth-error)
3. WAF blocked requests    → child: cloudwatch-alarm-logs-insights only
4. Unknown                   → NEEDS REVIEW (no Jira mutations)
```

### Bucket A — AWS Notification Message

**When:** `summary` === `AWS Notification Message` (exact).

**Action:** Read and execute **`jira-alr-aws-notification-triage`** in full for this ticket (all rules, flags, transitions, comments).

### Bucket B — RDS DB authentication failures

**When:** description or embedded JSON matches **any** of:

- `AuthenticationFailures`
- `"MetricName": "AuthenticationFailures"` with `"Namespace": "RM/RDS"`
- DB authentication failure wording in CloudWatch alarm text

**Action:**

1. **`cloudwatch-alarm-logs-insights`** — build Template B URL from alarm `Time:` (always for this bucket).
2. **`jira-alr-auth-error-triage`** — **only if** the user supplied **all** of for this ticket:
   - CloudWatch URL (use built URL if user omitted it)
   - Source IP
   - DB username
   - Assignee email
   If metadata is **missing** → output Logs Insights URL only; flag **`NEEDS METADATA`** in summary (do not assign or comment).

### Bucket C — WAF blocked requests

**When:** description matches **Bitwarden** or **platform** WAF patterns per **`cloudwatch-alarm-logs-insights`** Step 1b (Bitwarden before platform).

**Action:** **`cloudwatch-alarm-logs-insights`** only — build Template A or C URL. No assign, no status transition unless the user asks separately.

### Bucket D — Unknown

**When:** none of the above.

**Action:** No mutations. Summary row: alarm type `Unknown`, flag **`NEEDS REVIEW`**. Optionally ask for a saved Logs Insights URL or which child skill applies.

## Step 3 — Execute per bucket

Process tickets **bucket by bucket** (not strictly key order within a bucket is fine; final summary sorted by key).

- **Bucket A:** full aws-notification workflow per ticket.
- **Bucket B:** build URL first; auth-error triage only when metadata present.
- **Bucket C:** build URL only.
- **Bucket D:** skip.

Do **not** skip reading child `SKILL.md` files — they contain verbatim comments, ADF shapes, templates, and transition IDs.

## Step 4 — Combined summary (required)

After all tickets, output **one** table covering every input key:

```markdown
## ALR mixed triage summary

| Ticket | Route | Alarm type | Action | Final status | Flags |
| ------ | ----- | ---------- | ------ | ------------ | ----- |
| [ALR-xxxxx](https://razormetrics.atlassian.net/browse/ALR-xxxxx) | AWS Notification / RDS auth / WAF / Unknown | … | … | … | … |
```

**Route** = bucket name (`AWS Notification`, `RDS auth`, `WAF`, `Unknown`).

**Flags:** combine child skill flags: `NO ASSIGNEE`, `NO SPRINT`, `NEEDS REVIEW`, `NEEDS METADATA`, `UNMATCHED`, or `—`.

Highlight rows with any attention flag.

Below the table, add **subsections** only when non-empty:

- **Logs Insights URLs** — per ticket, plain URL or angle-bracket markdown link (from `cloudwatch-alarm-logs-insights`).
- **RDS auth pending** — list tickets missing IP / user / email.

## Step 5 — Chrome bulk-open (required)

End with **up to two** fenced JavaScript blocks (omit empty arrays):

### All Jira tickets from this run

```js
const ticketUrls = [
  'https://razormetrics.atlassian.net/browse/ALR-xxxxx',
];
ticketUrls.forEach((url, index) => {
  window.open(url, '_blank_alr_' + index);
});
```

### All CloudWatch Logs Insights URLs (if any)

```js
const urls = [
  'https://us-east-2.console.aws.amazon.com/cloudwatch/...',
];
urls.forEach((url, index) => {
  window.open(url, '_blank_cw_' + index);
});
```

Use double-quoted strings when URLs contain `'`. Tell the user: new Chrome tab → Console → paste array → Enter → paste `forEach` → Enter; allow pop-ups if blocked.

## Quick reference — what is fully automatic?

| Bucket | Keys only | Also updates Jira |
| ------ | --------- | ----------------- |
| AWS Notification Message | Yes (if assigned + rule match) | Comment + Done/Canceled |
| RDS auth | Logs Insights URL only | Assign + ADF comment **only with metadata** |
| WAF | Logs Insights URL only | No |
| Unknown | No | No |

## Example mixed paste

User: `Triage ALR-15552, ALR-13823, ALR-13742`
(+ optional table row for ALR-13742 with IP, user, email)

| Ticket | Route | Outcome |
| ------ | ----- | ------- |
| ALR-15552 | AWS Notification | SentinelOne PTRACE → comment + Done |
| ALR-13823 | WAF or RDS | Classify from description → URL |
| ALR-13742 | RDS auth | URL + assign/comment if metadata supplied |

Return one combined summary + `ticketUrls` + `urls` if applicable.
