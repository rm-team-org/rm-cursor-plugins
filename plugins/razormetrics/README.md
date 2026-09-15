# plugins/razormetrics/

RazorMetrics-authored plugins — internal skills, rules, MCP servers, or tools
built in-house rather than vendored from a third party.

Each plugin sits in its own folder directly under `plugins/razormetrics/`
(matching the layout used by every other plugin in this repo — see
`docs/REGISTRY.md`). After adding or changing one, run
`python3 tools/generate_marketplace.py` to refresh the marketplace listing.

## Plugins

- [`razormetrics-core`](razormetrics-core/) — internal Cursor skills (CloudWatch/Jira
  ALR alarm triage, Liquibase synthetic dataset authoring and validation) plus shared
  agent rules (requirements clarification, response formatting). Vendored from
  [rm_porcupine/rm_cursor_skills](https://bitbucket.org/rm_porcupine/rm_cursor_skills).
