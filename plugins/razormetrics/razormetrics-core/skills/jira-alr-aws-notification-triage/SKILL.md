---
name: jira-alr-aws-notification-triage
description: >-
  Triages ALR Jira tickets with summary "AWS Notification Message": classifies
  GuardDuty/runtime alarms from the description, cancels known ECS noise,
  comments false-positive templates, transitions to Done or Canceled, and
  returns a summary table plus Chrome bulk-open snippets. Use when the user
  provides ALR keys or links, asks to triage AWS notification alarms, or batch
  close GuardDuty/SentinelOne/Cybermaxx/kafka credential-exfiltration/portscan/SSH brute-force alerts.
---

# Jira ALR — AWS Notification Message triage

Automate triage for **ALR** issues whose **summary** is exactly `AWS Notification Message`. The issue **description** is usually a single-line JSON payload from AWS (GuardDuty EventBridge). Match rules against the **raw description string** (substring search is enough; fields like `title` inside the JSON count).

## Inputs

| Input | Example |
| ----- | ------- |
| Ticket key(s) | `ALR-16365`, `ALR-16366` |
| Browse URL(s) | `https://razormetrics.atlassian.net/browse/ALR-16365` |
| JQL (optional) | `project = ALR AND summary = "AWS Notification Message" AND status = Backlog` |

Process **one ticket at a time** in stable key order. Deduplicate keys.

## Tools (Atlassian MCP)

Use `plugin-atlassian-atlassian` or `user-Atlassian`:

1. **`getAccessibleAtlassianResources`** — resolve `cloudId` (or use `razormetrics.atlassian.net`).
2. **`getJiraIssue`** — fields: `summary`, `description`, `status`, `assignee`, `customfield_10021` (Sprint).
3. **`getTransitionsForJiraIssue`** — if a transition fails, re-fetch and pick by **transition name** (global transitions are usually stable on ALR).
4. **`addCommentToJiraIssue`** — `contentFormat`: `"markdown"` for the templates below (no CloudWatch URLs; markdown is fine).
5. **`transitionJiraIssue`** — `transition`: `{ "id": "<id>" }`.

**ALR global transition names (typical):**

| Target status | Transition name | Typical transition `id` |
| ------------- | --------------- | ------------------------- |
| Canceled | `Canceled` | `121` |
| Done | `Done` | `141` |

Always prefer the `id` from `getTransitionsForJiraIssue` when it differs.

**Sprint field:** `customfield_10021` — array of sprint objects. **No sprint** = field is `null` or `[]`.

## Per-ticket workflow

```text
1. Fetch issue; verify summary === "AWS Notification Message"
2. Record flags: no assignee? no sprint?
3. If no assignee → skip all mutations; go to summary row
4. Classify alarm type from description (rules below)
5. If matched → comment and/or transition per rule
6. If already Done / Canceled / Duplicate → note "already closed"; skip mutations unless user asked to re-run
7. If unmatched → no Jira changes; mark NEEDS REVIEW in summary
```

### Rule 1 — No assignee

If `assignee` is **null**: **do nothing** (no comment, no transition). Report in summary under **Flags** as `NO ASSIGNEE`.

### Rule 2 — No sprint

If `customfield_10021` is empty: still run the **normal** actions for the matched rule, but report **`NO SPRINT`** in summary **Flags** (can combine with other flags).

### Short description (rules 3–4 only)

**Short** = raw `description` length under **2500** characters **and** `detail-type` is `GuardDuty Runtime Protection Unhealthy` (present in the JSON). Reference tickets: [ALR-15118](https://razormetrics.atlassian.net/browse/ALR-15118), [ALR-16433](https://razormetrics.atlassian.net/browse/ALR-16433).

If not short, rules 3–4 do **not** apply even if the substring appears.

### Rule 3 — Unidentified ECS runtime issue → Canceled

**When:** short description **and** text contains:

`Unidentified issue, for task(s) in TaskDefinition`

**Action:** transition to **Canceled** (no comment). Reference: [ALR-15118](https://razormetrics.atlassian.net/browse/ALR-15118).

### Rule 4 — Agent not reporting → Canceled

**When:** short description **and** text contains:

`Agent not reporting, for task(s) in TaskDefinition`

**Action:** transition to **Canceled** (no comment). Reference: [ALR-16433](https://razormetrics.atlassian.net/browse/ALR-16433).

### Rule 5 — SentinelOne PTRACE → Done + comment

**When:** description contains:

`Process injection via PTRACE was detected in a resource`

**Action:** post comment (markdown below), then transition to **Done**. Reference: [ALR-15552](https://razormetrics.atlassian.net/browse/ALR-15552).

**Comment (verbatim):**

```text
Expected sentinelone behaviour.

The GuardDuty finding DefenseEvasion:Runtime/ProcessInjection.Ptrace is a false positive. The alert was triggered by the process sentinelone-agent (/opt/sentinelone/bin/sentinelone-agent), which is the core binary of the SentinelOne endpoint security agent running within the ECS cluster.

The agent used the PTRACE system call to inspect the grep process as part of its legitimate security monitoring and diagnostic function. GuardDuty's Runtime Monitoring flagged this inspection attempt as potential malicious process injection.

Details on the finding:

Threat: DefenseEvasion:Runtime/ProcessInjection.Ptrace indicates a program attempted to use the ptrace system call on another process.

Context: While attackers use ptrace to inject code, security tools use it to monitor execution flow.

Verification: The lineage shows the agent was launched via standard deployment scripts (deployment.sh) and is running in an authorized security container. No security incident has occurred.
```

### Rule 6 — Cybermaxx volume scan → Done + comment

**When:** description contains:

`security risk(s) detected including`

**Action:** post comment (markdown below), then transition to **Done**. Reference: [ALR-13721](https://razormetrics.atlassian.net/browse/ALR-13721).

**Comment (verbatim):**

```text
Expected vulnerability scanner behavior. The GuardDuty finding Execution:EC2/MaliciousFile is a false positive. The alert was triggered by an automated EBS volume scan detecting standard penetration testing tools and vulnerability signatures residing on our authorized Cybermaxx scanner instances.

Details on the finding:

Threat: Execution:EC2/MaliciousFile indicates known malware signatures were found on the EC2 instance's attached storage.

Context: The flagged files include OpenVAS Network Vulnerability Tests (NASL), Impacket scripts (used for authorized credential testing), and EICAR strings (industry-standard safe test files). Because these tools mimic attacker behavior or contain exploit code for testing purposes, security software naturally flags them.

Verification: The files are legitimate components of the Cybermaxx scanning engine. No malicious infection has occurred.
```

### Rule 7 — Kafka instance credential exfiltration → Done + comment

**When:** description contains:

`Credentials created exclusively for an EC2 instance using instance role rm_kafka_kafbat_prod_instance_profile_role have been used from external IP address`

**Action:**

1. Extract API name from description: find `"api":"CreateTopic"` (or `\"api\":\"CreateTopic\"` in escaped JSON). Use regex `"api":"([^"]+)"` on the raw description; use the captured value (e.g. `CreateTopic`) as `<api-endpoint>`.
2. Post comment below with `<api-endpoint>` replaced (no angle brackets in the posted comment).
3. Transition to **Done**. Reference: [ALR-15276](https://razormetrics.atlassian.net/browse/ALR-15276).

If the API cannot be extracted, still post the comment with `<api-endpoint>` literally **or** mark **NEEDS REVIEW** and skip transition — prefer **NEEDS REVIEW** if extraction fails.

**Comment template (replace `<api-endpoint>`):**

```text
This GuardDuty finding (InstanceCredentialExfiltration.OutsideAWS) is a false positive caused by our VPC networking configuration. There is no security breach.

The EC2 instance (rm_kafka_kafbat_prod) made a legitimate AWS API call (<api-endpoint>) using its assigned IAM role.

Our VPC is using the 172.61.0.0/16 CIDR block. Because this falls outside the standard RFC-1918 private IP range (172.16.0.0 - 172.31.255.255), GuardDuty sees it as an IP in the public space. When the instance makes an API call, GuardDuty incorrectly assumes the credentials have been exfiltrated and are being used from the public internet.
```

### Rule 8 — Cybermaxx outbound portscan → Done + comment

**When:** description contains:

`An outbound portscan was detected from EC2 instance`

**and** the description contains at least one **authorized Cybermaxx scanner** instance ID from this list:

| Instance ID |
| ----------- |
| `i-07e6506c4f6086512` |
| `i-0d03eca37ce960f15` |
| `i-0b9cdba03999a3bbd` |
| `i-03381c0ae1bcf2e9e` |
| `i-02f5f05daa6b71b20` |

Instance IDs usually appear in the JSON `title` (e.g. `...from EC2 instance i-02f5f05daa6b71b20.`) or `"instanceId":"i-..."`. Substring match on the raw description is sufficient.

If the portscan text matches but **no** listed instance ID is present → **NEEDS REVIEW** (no comment, no transition).

**Action:** post comment (markdown below), then transition to **Done**. Reference: [ALR-14946](https://razormetrics.atlassian.net/browse/ALR-14946).

**Comment (verbatim):**

```text
Expected vulnerability scanner behavior. The GuardDuty finding Recon:EC2/Portscan is a false positive. The alert was triggered by an authorized Cybermaxx vulnerability scanning instance performing a routine network discovery scan against internal infrastructure.

Details on the finding:

Threat: Recon:EC2/Portscan indicates an EC2 instance is probing a remote host for open ports.

Context: While attackers use port scanning to map networks for vulnerabilities, authorized scanning tools perform the exact same action to audit our infrastructure and discover exposed services.

Verification: The source instance is a known, authorized vulnerability scanner deployed for this specific purpose. No malicious compromise has occurred.
```

### Rule 9 — Cybermaxx SSH brute force → Done + comment

**When:** description contains:

`Brute force attacks are used to gain unauthorized access to your instance by guessing the SSH password`

**and** the description contains at least one **authorized Cybermaxx scanner source IP** from this list:

| Source IP |
| --------- |
| `172.71.10.104` |
| `172.40.3.195` |
| `172.61.13.233` |
| `172.41.14.64` |
| `172.22.13.101` |
| `172.61.59.82` |

Source IPs usually appear as the scanner's `localIpDetails.ipAddressV4`, `privateIpAddress`, or in the JSON `title` / `description` (e.g. [ALR-13722](https://razormetrics.atlassian.net/browse/ALR-13722) uses `172.61.13.233` as the actor). Substring match on the raw description is sufficient.

If the SSH brute-force text matches but **no** listed source IP is present → **NEEDS REVIEW** (no comment, no transition).

**Action:** post comment (markdown below), then transition to **Done**. Reference: [ALR-13722](https://razormetrics.atlassian.net/browse/ALR-13722).

**Comment (verbatim):**

```text
Expected vulnerability scanner behavior. The GuardDuty finding UnauthorizedAccess:EC2/SSHBruteForce is a false positive. The alert was triggered during an authorized credential auditing scan, where the Cybermaxx scanning instance (cybermaxx-vulnerability-scan-vpc-production) tested the SSH service of the SFTP server (sftp-production-secure) for weak or default passwords.

Details on the finding:

Threat: UnauthorizedAccess:EC2/SSHBruteForce indicates repeated, rapid SSH login failures, characteristic of a script guessing passwords.

Context: Authorized vulnerability scanners automatically perform SSH brute-forcing as part of their standard credential and configuration checks.

Verification: The traffic originated from our internal, authorized Cybermaxx scanning instance. This was a scheduled security audit, not an actual compromise attempt.
```

## Classification order

Evaluate **after** rule 1 (assignee). For assigned tickets, test in this order (first match wins):

1. Rule 7 — Kafka credential exfiltration
2. Rule 5 — PTRACE / SentinelOne
3. Rule 6 — Cybermaxx security risks (MaliciousFile)
4. Rule 8 — Cybermaxx outbound portscan (authorized instance IDs only)
5. Rule 9 — Cybermaxx SSH brute force (authorized source IPs only)
6. Rule 3 — Unidentified TaskDefinition (short only)
7. Rule 4 — Agent not reporting (short only)
8. No match → **NEEDS REVIEW**

Rules 3–4 only apply when **short**; rules 5–9 do not require short description.

## Required summary table

After **all** tickets are processed, output:

```markdown
## AWS Notification Message triage summary

| Ticket | Alarm type | Action | Final status | Flags |
| ------ | ---------- | ------ | ------------ | ----- |
| [ALR-xxxxx](https://razormetrics.atlassian.net/browse/ALR-xxxxx) | … | … | … | … |
```

**Column guidance:**

- **Alarm type:** e.g. `ECS unidentified`, `ECS agent not reporting`, `SentinelOne PTRACE`, `Cybermaxx MaliciousFile`, `Cybermaxx Portscan`, `Cybermaxx SSHBruteForce`, `Kafka credential exfiltration`, `Portscan (unknown instance)`, `SSH brute force (unknown source IP)`, `Unknown`, `Skipped (no assignee)`.
- **Action:** e.g. `Canceled`, `Comment + Done`, `None`, `Already Canceled`.
- **Final status:** status after triage (or current if skipped).
- **Flags:** semicolon-separated: `NO ASSIGNEE`, `NO SPRINT`, `NEEDS REVIEW`, or `—`.

Highlight rows that need human attention: **NO ASSIGNEE**, **NO SPRINT**, **NEEDS REVIEW**, or **UNMATCHED** (same as NEEDS REVIEW).

## Chrome — bulk open tickets

End every triage run with a fenced JavaScript block listing **every ticket key** from the run (processed or skipped), deduplicated, sorted by key:

```js
const urls = [
  'https://razormetrics.atlassian.net/browse/ALR-16365',
  'https://razormetrics.atlassian.net/browse/ALR-16366',
];
urls.forEach((url, index) => {
  window.open(url, '_blank_alr_' + index);
});
```

**User steps:** Open a **new** Chrome tab → DevTools **Console** → paste the `const urls = [...]` array → Enter → paste the `forEach` → Enter. Allow pop-ups if prompted.

## Related skills

- Mixed batch routing (start here for heterogeneous ALR lists): **`jira-alr-alarm-triage-router`**
- RDS auth alarms + Logs Insights comments: **`jira-alr-auth-error-triage`**
- CloudWatch Logs Insights URL construction: **`cloudwatch-alarm-logs-insights`**
