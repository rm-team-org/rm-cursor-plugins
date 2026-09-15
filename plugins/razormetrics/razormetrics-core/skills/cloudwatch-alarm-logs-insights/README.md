# cloudwatch-alarm-logs-insights

## What it does

Builds **CloudWatch Logs Insights** console URLs around an ALR alarm time: parses UTC from the issue (or Jira), applies a **±30 minute** window with console-specific encoding (`*` colons as `*3a`), and selects the right **saved-query template**—WAF BLOCK by IP for the **platform** ALB log group, WAF BLOCK by IP for the **Bitwarden** ALB log group (ARN `source`, e.g. ALR-14509), RDS DB authentication failures (all three Aurora PostgreSQL cluster log groups), or a user-supplied saved URL. Output is for the user to open in a browser; the agent does not fetch or curl these URLs.

Whenever the skill emits **one or more** Logs Insights URLs in the same answer, it **ends** with a `**const urls = [ ... ];`** block (every CloudWatch URL in stable order) plus steps to open them all in Chrome via the Console. When the answer references **one or more Jira issues**, it also appends a **separate** `**const ticketUrls = [ ... ];`** block (canonical `/browse/KEY` URLs, deduped) and matching Console steps so ticket tabs open in one shot—see **Batch output** below and `SKILL.md` (section *Final output — URL array and open all in Chrome*).

## When to use

ALR tickets, CloudWatch alarm triage, or any request for a Logs Insights link tied to an alarm `Time:` line.

## Usage (inputs)

- **Timestamp:** ISO-like UTC strings, e.g. `2026-04-05T20:25:10.474Z` or `...+0000`.
- **Jira:** Issue key(s) or browse URL(s); the skill reads the description and regex-matches `Time: <ISO>`.

**Output:** Plain URL (default, easy copy) or a **markdown link** with an angle-bracket destination `<url>` so `)` in the hash does not break the link.

## Batch output (Chrome)

After per-ticket URLs (and optional markdown links), the skill **always** appends for CloudWatch:

1. A fenced JavaScript `**const urls = [ ... ];`** listing **every** Logs Insights URL from that response (order: e.g. ticket key ascending). Use double-quoted strings or escapes when URLs contain literal `'` (common in CloudWatch hash fragments).
2. Instructions for the user to open **all** CloudWatch tabs at once:
  1. Open a **new tab** in Chrome (**important:** use a new tab).
  2. Open **Developer Tools** → **Console** on that tab, paste the `**urls`** array, press Enter.
  3. Paste and run:

```js
urls.forEach((url, index) => {
  window.open(url, '_blank_cw_' + index);
});
```

If the response references **one or more Jira alarm tickets**, the skill **also** appends (in a **separate** fenced block):

1. `**const ticketUrls = [ ... ];`** with full browse URLs (`https://<site>/browse/KEY`), deduped and ordered (e.g. key ascending).
2. The same Console workflow: paste `**ticketUrls**`, then run:

```js
ticketUrls.forEach((url, index) => {
  window.open(url, '_blank_ticket_' + index);
});
```

Chrome may block multiple pop-ups until allowed for that context. Prefixes `_blank_cw_` and `_blank_ticket_` keep CloudWatch and Jira opens from colliding if the user runs both snippets in the same session.

## MCP (Atlassian)

When resolving time from Jira:

1. `**getAccessibleAtlassianResources`** — resolve `cloudId` / site if needed.
2. `**searchJiraIssuesUsingJql`** — e.g. `key = ALR-13719`, include description; extract `Time:` from the body.

Prefer MCP over raw HTTP to Jira.

## Example

**RDS authentication alarm** (`AuthenticationFailures`): Even if `AlarmName` names one cluster, Template B searches **all three** encoded sources (`rm-rxa-production`, `rm-rxa-prerelease`, `rm-everest` PostgreSQL log groups). For alarm time `2026-04-09T19:16:31.665+0000`, normalize to seconds, window **18:46:31–19:46:31 UTC**, encode start/end into the hash, substitute into Template B — user opens the URL in us-east-2 Logs Insights.

**WAF — platform:** Same ±30 minute window; Template A targets `aws-waf-logs-loadbalancer/platform/production` with the BLOCK-by-IP query.

**WAF — Bitwarden:** Same window and same query as platform WAF; Template C uses `source` with the log-group ARN for `aws-waf-logs-alb/bitwarden/prod` in us-east-2 (see SKILL Step 1c / Template C). Use when the ticket matches the Bitwarden ALB WAF alarm family (e.g. ALR-14509).

Unknown alarm types: ask for a saved Logs Insights URL from the console and only replace absolute `start`/`end` (convert relative → absolute if needed).



.
