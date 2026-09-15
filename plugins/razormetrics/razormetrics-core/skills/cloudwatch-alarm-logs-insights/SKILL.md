---
name: cloudwatch-alarm-logs-insights
description: >-
  Builds CloudWatch Logs Insights console URLs around an ALR alarm time: parses a
  UTC timestamp from the issue, expands a ±30 minute window with
  millisecond-normalized bounds, encodes times into the AWS console hash format
  (*3a for colons), picks the right query template from the alarm type (WAF
  BLOCK — platform ALB, WAF BLOCK — Bitwarden ALB, RDS authentication failed
  logs, or user-supplied URL), and optionally
  reads Jira via Atlassian MCP. For RDS auth alarms, searches **all three**
  standard cluster PostgreSQL log groups in `source` (see Step 1c). Supports
  plain URLs or markdown links ([label](<url>)). When one or more Logs Insights
  URLs are produced in the same answer, end with a single `const urls = [...]`
  block plus Chrome steps to open every CloudWatch link at once; when the answer
  references one or more Jira issues, also end with a separate `const
  ticketUrls = [...]` block and matching Chrome steps for all ticket links (see
  final section). Use for ALR
  tickets, CloudWatch alarm investigations, or when the user asks for a Logs
  Insights link tied to an alarm time.
---

# CloudWatch alarm (ALR) → Logs Insights URL

## Constraints

- **Never HTTP-fetch or “open” the resulting URL** in automation (no `curl`, no browser invocation by the agent). Only construct it for the user to paste into the browser.
- Preserve the rest of each template (`editorString`, `queryId`, `region`, etc.) unless the user supplies a different base URL—only substitute **time bounds** (and switch relative → absolute when needed), and for RDS **source log group(s)** per Step 1c.

## Output format (plain URL vs markdown link)

When delivering the Logs Insights URL to the user:

- **Default:** Output the **full URL on its own** (fenced code block or bare line) so it can be copied intact.
- **Markdown link:** If the user asks for a **clickable / formatted link**, or if chat context favors rich text (Slack, Jira comments, docs), also give a **markdown link**.

**Wrapping the destination:** Console URLs contain `)` inside the hash fragment (for example around `source~(...)`). A naive `[label](https://...)` stops at the **first** `)`, which breaks the link. Use an **angle-bracket destination**:

```markdown
[CloudWatch Logs Insights — RDS auth failed (ALR-13823)](<PASTE_FULL_URL_HERE>)
```

Replace the label with something short and specific (ticket key, alarm name, or UTC window). **Do not** alter or truncate the URL inside the angle brackets.

Offer **both** when helpful: markdown link for clicking, and the same URL in a code block for copy/paste if the renderer mangles long links.

**Batch closure:** If you output **any** constructed Logs Insights URL(s) in one response (one ticket or many), **always** finish with the **compiled `urls` array** and the **Chrome DevTools steps** for CloudWatch in [Final output — URL array and open all in Chrome](#final-output--url-array-and-open-all-in-chrome). Keep per-ticket URLs/links above that block unchanged.

If the same answer references **one or more Jira issue(s)** (keys or browse URLs you used or cited), **also** append the **compiled `ticketUrls` array** in its **own** fenced block and the **Chrome steps for tickets** from that section (separate from the CloudWatch block so each can be pasted and run independently).

## Input formats

### A) Raw timestamp

Accept ISO-like strings such as:

- `2026-04-05T20:25:10.474+0000`
- `2026-04-05T20:25:10.474Z`

### B) Jira ticket(s)

Accept one or more links or keys, e.g. `https://razormetrics.atlassian.net/browse/ALR-13719` or `ALR-13719`.

## Step 1 — Resolve the alarm time

**From a timestamp:** Parse as UTC. Drop sub-second precision: treat the instant as **whole seconds**, then format bounds with **`.000`**.

**From Jira:**

1. Resolve `cloudId` if needed: call Atlassian MCP `getAccessibleAtlassianResources`, or pass the site hostname (e.g. `razormetrics.atlassian.net`) as `cloudId` per tool docs.
2. Fetch issues with Atlassian MCP `searchJiraIssuesUsingJql`:
   - Single issue: `key = ALR-13719`
   - Multiple: `key in (ALR-13719, ALR-13720)`
   - Include `description` in `fields` (default already includes it).
3. In the **description**, find a line matching:

   `Time: 2026-04-05T21:46:10.473+0000`

   Regex (flexible):

   ```text
   Time:\s*(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{4}))
   ```

4. If multiple tickets: produce **one URL per extracted time** (or one per ticket if each has its own `Time:` line). State which ticket each URL belongs to.

## Step 1b — Detect alarm type and choose a template

Use the **description** and embedded **CloudWatch Details** JSON when present.

| Kind | How to recognize | Action |
|------|------------------|--------|
| **WAF — Bitwarden ALB blocked requests** | `AlarmName` / summary / description mentions Bitwarden WAF or blocked requests for Bitwarden; embedded JSON or text references log group `aws-waf-logs-alb/bitwarden/prod` or an ARN containing that segment; example ticket family: [ALR-14509](https://razormetrics.atlassian.net/browse/ALR-14509) | Use **Template C** (same BLOCK-by-IP query as Template A, Bitwarden prod log group — Step 1c). |
| **WAF — platform ALB blocked requests** | `AlarmName` / summary contains `rm-platform-waf-alb-production` and `blocked-requests`, or JSON has `"Namespace": "AWS/WAFV2"` and blocked-request style alarm for the platform ALB (not Bitwarden) | Use **Template A** (WAF BLOCK by IP, platform production log group). |
| **RDS — DB authentication failures** | `AlarmName` / summary contains `AuthenticationFailures`, or JSON has `"MetricName": "AuthenticationFailures"` and `"Namespace": "RM/RDS"` (or description says DB authentication failures) | Use **Template B** (PostgreSQL — authentication failed; excludes `rdsadmin`). **`source`** includes **all three** cluster log groups per Step 1c (not just the cluster named in `AlarmName`). |
| **Unknown / custom** | Does not match above | Ask for a **saved Logs Insights URL** from the console (or paste query + log groups). Reuse that URL’s `editorString`, `source`, `queryId`, and `region`—only recompute **absolute** `start`/`end` per Steps 2–4. If the pasted URL uses **relative** time (`timeType~'RELATIVE`, `end~0`, `start~-NNN`, `unit~'seconds`), **replace** that block with the absolute block from Step 4. |

**Detection order:** Prefer **Bitwarden** (Template C) when the issue text or JSON clearly names Bitwarden or `aws-waf-logs-alb/bitwarden/prod`; otherwise use the platform ALB row (Template A) when it matches.

**Region:** Templates below assume **us-east-2** (Ohio), matching typical RM production alarms. If the JSON says another region, swap the `region=` query parameter and console hostname if needed.

## Step 1c — Resolve log group(s) for the Insights `source`

### WAF — platform ALB (Template A)

Log group is **fixed** for this alarm family unless the user supplies another URL:

- Path: `aws-waf-logs-loadbalancer/platform/production`
- In the hash: `aws-waf-logs-loadbalancer*2fplatform*2fproduction` (`/` → `*2f`).

Use exactly: `source~(~'aws-waf-logs-loadbalancer*2fplatform*2fproduction)~lang`.

### WAF — Bitwarden ALB (Template C)

Saved links for this family often use a **log-group ARN** in `source` (same query as Template A: BLOCK by IP). Fixed values unless the user pastes a different base URL:

- Log group path: `aws-waf-logs-alb/bitwarden/prod`
- ARN (us-east-2, account `552531424244`): `arn:aws:logs:us-east-2:552531424244:log-group:aws-waf-logs-alb/bitwarden/prod`

**Encode** the ARN for the hash: `:` → `*3a`, `/` in the log group suffix → `*2f`:

```text
arn*3aaws*3alogs*3aus-east-2*3a552531424244*3alog-group*3aaws-waf-logs-alb*2fbitwarden*2fprod
```

Use exactly: `source~(~'arn*3aaws*3alogs*3aus-east-2*3a552531424244*3alog-group*3aaws-waf-logs-alb*2fbitwarden*2fprod)~lang`.

If CloudWatch Details show a **different** region, account, or log group name, rebuild the ARN segment from that JSON (same encoding rules) or ask the user for their saved Logs Insights URL and only replace `start`/`end`.

### RDS PostgreSQL — `AuthenticationFailures` (Template B)

For **AuthenticationFailures** alarms, **always** search **all three** standard RM Aurora cluster PostgreSQL log groups (same query runs across every `source` entry):

| Cluster (from `AlarmName` middle segment, for context only) | Log group path |
|--------------------------------------------------------------|----------------|
| `rm-rxa-production` | `/aws/rds/cluster/rm-rxa-production/postgresql` |
| `rm-rxa-prerelease` | `/aws/rds/cluster/rm-rxa-prerelease/postgresql` |
| `rm-everest` | `/aws/rds/cluster/rm-everest/postgresql` |

**Encode** each path for the hash: replace every **`/`** with **`*2f`**. Concatenate in **`source`** in this exact order (tilde-separated inside `source~(...)`):

```text
source~(~'*2faws*2frds*2fcluster*2frm-rxa-production*2fpostgresql~'*2faws*2frds*2fcluster*2frm-rxa-prerelease*2fpostgresql~'*2faws*2frds*2fcluster*2frm-everest*2fpostgresql)~lang
```

Use this **fixed triple** in Template B. Do **not** reduce to a single cluster for auth-failure triage unless the user explicitly asks for one log group only.

If RM adds or renames clusters later, update the three paths above and the encoded `source` segment to match.

## Step 2 — Compute the window

Let `T` be the parsed instant, normalized to **second** precision (fractional seconds discarded).

- **start** = `T` minus 30 minutes
- **end** = `T` plus 30 minutes

Format both as UTC strings:

`YYYY-MM-DDTHH:mm:ss.000Z`

Example:

- Input: `2026-04-05T20:25:10.474+0000` → normalized `2026-04-05T20:25:10Z`
- start: `2026-04-05T19:55:10.000Z`
- end: `2026-04-05T20:55:10.000Z`

## Step 3 — Encode times for the console URL

In the **hash fragment** (`#logsV2:logs-insights$3FqueryDetail$3D~(...)`), datetime segments use a special encoding: **each colon `:` is written as `*3a`** (same as `%3A` with `*` instead of `%`).

Apply only to the date-time literals you substitute, e.g.:

| Literal | Encoded segment |
|-----------|-----------------|
| `2026-04-05T20:55:10.000Z` | `2026-04-05T20*3a55*3a10.000Z` |

## Step 4 — Patch the URL

**Parameter names:** In these console URLs, **`end` is the later bound** and **`start` is the earlier bound** (matches the ±30 minute window).

### Absolute time block (all templates)

Substitute encoded **start** and **end** into:

```text
end~'END_ENCODED~start~'START_ENCODED~timeType~'ABSOLUTE~tz~'UTC
```

**WAF templates (A and C)** already use this block immediately before `~editorString~'`.

**RDS template B** (and any **relative** URL you convert): replace the **entire** relative segment:

```text
end~0~start~-3600~timeType~'RELATIVE~tz~'UTC~unit~'seconds
```

with the **absolute** segment above (no `unit~'seconds`). Do **not** leave relative mode if the goal is an alarm-correlated window.

### Template A — WAF BLOCK by IP (platform ALB log group — **do not fetch**)

```text
https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#logsV2:logs-insights$3FqueryDetail$3D~(end~'END_ENCODED~start~'START_ENCODED~timeType~'ABSOLUTE~tz~'UTC~editorString~'fields*20httpRequest.clientIp*20as*20ip*0a*7c*20filter*20action*20*3d*20*27BLOCK*27*0a*7c*20stats*20count*28*2a*29*20as*20requestCount*20by*20ip*0a*7c*20sort*20requestCount*20desc~queryId~'817eaa34-0209-4cc4-a01c-c3373d839360~source~(~'aws-waf-logs-loadbalancer*2fplatform*2fproduction)~lang~'CWLI~logClass~'STANDARD~queryBy~'logGroupName)
```

Replace `START_ENCODED` and `END_ENCODED` with the values from Step 3.

### Template C — WAF BLOCK by IP (Bitwarden ALB log group — **do not fetch**)

Same query and `queryId` as Template A; `source` uses the ARN form from Step 1c (example: [ALR-14509](https://razormetrics.atlassian.net/browse/ALR-14509)).

```text
https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#logsV2:logs-insights$3FqueryDetail$3D~(end~'END_ENCODED~start~'START_ENCODED~timeType~'ABSOLUTE~tz~'UTC~editorString~'fields*20httpRequest.clientIp*20as*20ip*0a*7c*20filter*20action*20*3d*20*27BLOCK*27*0a*7c*20stats*20count*28*2a*29*20as*20requestCount*20by*20ip*0a*7c*20sort*20requestCount*20desc~queryId~'817eaa34-0209-4cc4-a01c-c3373d839360~source~(~'arn*3aaws*3alogs*3aus-east-2*3a552531424244*3alog-group*3aaws-waf-logs-alb*2fbitwarden*2fprod)~lang~'CWLI~logClass~'STANDARD~queryBy~'logGroupName)
```

Replace `START_ENCODED` and `END_ENCODED` with the values from Step 3.

### Template B — RDS PostgreSQL: “authentication failed” (three cluster log groups — **do not fetch**)

Use for **AuthenticationFailures** alarms (example Jira: [ALR-13823](https://razormetrics.atlassian.net/browse/ALR-13823)). Query mirrors console saved query id `bb6abe14-c215-4c4b-a764-50deb8ae35e6`: `@message` matches authentication failed, excludes `rdsadmin@rdsadmin`. **`source`** always includes **all three** clusters from Step 1c.

```text
https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#logsV2:logs-insights$3FqueryDetail$3D~(end~'END_ENCODED~start~'START_ENCODED~timeType~'ABSOLUTE~tz~'UTC~editorString~'fields*20*40logStream*2c*20*40message*2c*20*40timestamp*0a*7c*20filter*20*40message*20like*20*2fauthentication*20failed*2f*20and*20*40message*20not*20like*20*2frdsadmin*40rdsadmin*2f*0a*7c*20sort*20*40timestamp*20desc~queryId~'bb6abe14-c215-4c4b-a764-50deb8ae35e6~source~(~'*2faws*2frds*2fcluster*2frm-rxa-production*2fpostgresql~'*2faws*2frds*2fcluster*2frm-rxa-prerelease*2fpostgresql~'*2faws*2frds*2fcluster*2frm-everest*2fpostgresql)~lang~'CWLI~logClass~'STANDARD~queryBy~'logGroupName)
```

Replace `START_ENCODED` and `END_ENCODED` with the values from Step 3 only. Do **not** remove or subset the three log groups unless the user asks for a narrower scope.

**Note:** A saved console link may use **relative** last hour (`end~0~start~-3600~...~RELATIVE~...~unit~'seconds`). For alarm triage, always **rewire** to **absolute** bounds around the `Time:` line using this template.

### Worked example (WAF — Template A or C — sanity check)

Alarm time: `2026-04-05T20:25:10.474+0000` → window end `2026-04-05T20:55:10.000Z`, start `2026-04-05T19:55:10.000Z`.

Encoded:

- end: `2026-04-05T20*3a55*3a10.000Z`
- start: `2026-04-05T19*3a55*3a10.000Z`

Substitute those into **Template A** (platform) or **Template C** (Bitwarden ARN `source`) depending on alarm type; time window logic is identical.

### Worked example (WAF Bitwarden — URL shape)

For alarm time `2026-04-24T23:30:00.000Z` (second-normalized): start `2026-04-24T23:00:00.000Z`, end `2026-04-25T00:00:00.000Z`. Encode colons and plug into Template C — matches the same ±30 minute convention as the other alarm templates (the sample console link used a one-hour calendar slice; this skill always uses **±30 minutes** around `T`).

### Worked example (RDS — ALR-13823)

`AlarmName`: `production:rm-rxa-production:AuthenticationFailures` — still use Template B with **all three** `source` log groups (production, prerelease, everest).

Alarm time: `2026-04-09T19:16:31.665+0000` → normalized second `2026-04-09T19:16:31Z` → start `2026-04-09T18:46:31.000Z`, end `2026-04-09T19:46:31.000Z`. Encode colons in those two literals and substitute into Template B.

## Edge cases

- **No `Time:` in description:** Tell the user; ask for a timestamp or paste of the alarm body.
- **Ambiguous timezone:** Prefer parsing explicit offset/`Z`; if missing, do not guess—ask.
- **Alarm type unclear:** Use detection table; if still unclear, ask for a saved Logs Insights URL or alarm JSON snippet, then reuse query + sources with new absolute times.
- **Different log groups or query:** If the user provides another Logs Insights URL, reuse their `editorString`, `source`, `queryId`, and region—only recompute `start`/`end` (and relative → absolute as above).

## Reference: Atlassian MCP

| Step | Tool |
|------|------|
| Resolve site / `cloudId` | `getAccessibleAtlassianResources` |
| Load issue(s) + description | `searchJiraIssuesUsingJql` with `jql` on `key` |

Do not use raw HTTP to Jira when MCP is available.

## Final output — URL array and open all in Chrome

After listing individual URLs (and optional markdown links), **always** append this when the same answer contains **one or more** generated CloudWatch Logs Insights URLs.

### Compiled array — CloudWatch Logs Insights

Output **one** fenced JavaScript block containing every Logs Insights URL from that answer, in a stable order (e.g. ticket key ascending, or the order you already presented). Use this shape:

```js
const urls = [
  'https://…',
  'https://…',
];
```

**String quoting:** Prefer **single-quoted** strings if the URL has no `'` characters after encoding. If a URL contains literal single quotes (common in these console hashes: `end~'…`), use **double-quoted** strings (`"https://…"`) or escape `\'` inside single quotes so the snippet is valid JavaScript.

Optionally add a short comment above the array mapping indices to ticket keys or alarm times.

### User steps (Chrome) — CloudWatch

Tell the user to open **all** Logs Insights links in separate tabs **without** clicking each long URL manually:

1. Open a **new tab** in Chrome. (**Important:** use a **new tab** — not reusing a tab where pop-ups are blocked from prior navigations, if possible.)
2. In that tab, open **Developer Tools** → **Console** (`F12`, or `Cmd+Option+I` / `Ctrl+Shift+I`, then select **Console**). Paste the **`const urls = [ ... ];`** array definition from your answer and press Enter.
3. Paste **exactly** this code and press Enter:

```js
urls.forEach((url, index) => {
  // Unique window name prevents overwriting the same tab
  window.open(url, '_blank_cw_' + index);
});
```

The array and script must run in the **Console** (step 2–3); the **new tab** (step 1) is the context where those runs should happen.

**Notes:** Chrome may block multiple `window.open` calls until the user allows pop-ups for the site (or “always allow” for that tab). The distinct target name `'_blank_cw_' + index` avoids every open targeting the same `_blank` window and replacing the previous tab.

### Compiled array — Jira alarm ticket links

When the answer involves **one or more Jira issues** (ALR keys, browse URLs, or issues fetched via MCP), output a **second** fenced JavaScript block **after** the CloudWatch batch (or alone if you listed ticket links but built no Logs Insights URLs—rare). Include **every** relevant issue as a full **browse** URL (`https://<site>/browse/KEY`), **deduplicated**, stable order (e.g. key ascending):

```js
const ticketUrls = [
  'https://razormetrics.atlassian.net/browse/ALR-13823',
  'https://razormetrics.atlassian.net/browse/ALR-13719',
];
```

Use the site hostname from the ticket(s) or MCP resource (e.g. `razormetrics.atlassian.net`). If the user only gave keys, normalize to canonical browse URLs.

### User steps (Chrome) — Jira tickets

Use the **same tab / Console context** as above (or a fresh new tab if preferred). Paste **`const ticketUrls = [ ... ];`** and press Enter, then run:

```js
ticketUrls.forEach((url, index) => {
  window.open(url, '_blank_ticket_' + index);
});
```

**Ordering:** If the user opens **both** CloudWatch and ticket batches, they may paste `urls`, run the CloudWatch `forEach`, then paste `ticketUrls`, run the ticket `forEach`. Prefixes `_blank_cw_` and `_blank_ticket_` keep targets distinct so one batch does not reuse windows from the other.

**Notes:** Same pop-up caveats as CloudWatch. Skip the `ticketUrls` block entirely when the answer has **no** Jira issue references (e.g. raw timestamp-only input with no keys).
