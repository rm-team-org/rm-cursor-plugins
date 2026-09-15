---
name: jira-alr-auth-error-triage
description: >-
  Triages RDS DB authentication ALR tickets in Jira: assigns an issue to a user by
  email, posts a CloudWatch Logs Insights comment with correct link handling (ADF,
  not raw markdown), and returns a summary with clickable ticket links. Use when
  the user provides ticket key(s), CloudWatch query URL, source IP, DB username,
  and assignee email; or when updating ALR CloudWatch auth-error tickets after
  investigation.
---

# Jira ALR auth error triage (assign + Logs Insights comment)

## Inputs (per ticket)

| Input | Example |
| ----- | ------- |
| Ticket number | `ALR-13742` |
| CloudWatch link | Full Logs Insights console URL for that alarm window |
| IP | `172.16.1.89` |
| Name | DB user from logs (e.g. `shaheer.aamir`) |
| Email | Assignee, e.g. `shaheer.aamir@razormetrics.com` |

For multiple tickets, repeat the workflow once per row (each ticket may have a **different** CloudWatch URL and metadata).

## Tools

Use **Atlassian MCP** (`user-Atlassian` or equivalent):

1. **`getAccessibleAtlassianResources`** — resolve `cloudId` if unknown (or pass site hostname, e.g. `razormetrics.atlassian.net`, per tool docs).
2. **`lookupJiraAccountId`** — `searchString` = assignee email → `accountId`.
3. **`editJiraIssue`** — set assignee:
   - `fields.assignee` = `{ "accountId": "<from lookup>" }`
4. **`addCommentToJiraIssue`** — post comment using **`contentFormat`: `"adf"`** (see below).

Do not paste the CloudWatch URL as plain **markdown** body text: the URL contains `*` characters that Jira interprets as emphasis and **corrupts** the link. Do not use `contentFormat: "markdown"` with the raw URL on its own line.

## Workflow

1. **Go to the ticket** — Use the issue key with MCP (`issueIdOrKey`). Optionally give the user `[Browse ALR-xxxxx](https://razormetrics.atlassian.net/browse/ALR-xxxxx)` in chat.
2. **Assign** — Look up `accountId` by email; call `editJiraIssue` with `assignee`.
3. **Comment** — Build **ADF** as JSON, then pass **`commentBody`** as **`JSON.stringify(adf)`** and **`contentFormat`: `"adf"`**.

### Comment template (semantic content)

Rendered result:

- First line: the phrase **CloudWatch Logs Insights** as hyperlink text; **`href`** = full CloudWatch URL (exact string from input, unchanged).
- Second paragraph: auth attribution using IP and name for the associated workspace.

Exact wording of the second paragraph:

```text
Auth errors caused by <IP>, with user <name> for the associated workspace
```

Substitute `<IP>` and `<name>` with the provided values. Use the **ADF** structure below so the link survives Jira’s markdown pipeline.

### ADF JSON shape

`commentBody` must be a **string** containing stringified JSON like:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "CloudWatch Logs Insights",
          "marks": [
            {
              "type": "link",
              "attrs": {
                "href": "<PASTE_FULL_CLOUDWATCH_URL_HERE>"
              }
            }
          ]
        }
      ]
    },
    {
      "type": "paragraph",
      "content": [
        {
          "type": "text",
          "text": "Auth errors caused by <IP>, with user <name> for the associated workspace"
        }
      ]
    }
  ]
}
```

Replace `<PASTE_FULL_CLOUDWATCH_URL_HERE>`, `<IP>`, and `<name>` with actual values. Escape the JSON correctly when sending to the MCP (the entire ADF document is one string field).

## Summary (required user-facing output)

After all tickets are processed, post a **short summary** in the chat that includes:

1. **Clickable ticket links** — Markdown: `[ALR-xxxxx](https://razormetrics.atlassian.net/browse/ALR-xxxxx)` for each issue.
2. **Assignee** — Display name and email used.
3. **Comment** — State that an ADF comment was posted on each ticket with the Logs Insights hyperlink and the auth line (`IP` / `name`). Optionally include returned **comment id** from the API if present.

Example shape:

```markdown
## Triage summary

| Ticket | Assignee | Note |
| ------ | -------- | ---- |
| [ALR-13742](https://razormetrics.atlassian.net/browse/ALR-13742) | Shaheer Aamir (shaheer.aamir@razormetrics.com) | ADF comment posted |
| [ALR-13741](https://razormetrics.atlassian.net/browse/ALR-13741) | … | … |

- **Comments:** Each issue received the CloudWatch Logs Insights link (clickable) and the sentence *Auth errors caused by …, with user … for the associated workspace*.
```

## Related skills

- Mixed batch routing (start here for heterogeneous ALR lists): **`jira-alr-alarm-triage-router`**
- Building Logs Insights URLs from alarm times: **`cloudwatch-alarm-logs-insights`**
- GuardDuty / AWS Notification Message triage: **`jira-alr-aws-notification-triage`**
