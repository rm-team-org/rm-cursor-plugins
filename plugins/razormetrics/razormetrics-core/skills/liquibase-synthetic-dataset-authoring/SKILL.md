---
name: liquibase-synthetic-dataset-authoring
description: >-
  Authors isolated synthetic datasets in rm_db_migrations_liquibase with
  deterministic fixtures, dedicated manifests, FK-safe ordering, scenario
  documentation, and restore verification. Use when creating or extending
  an isolated dataset folder under test_data/<db_type>/dml/<dataset>/,
  its dml_restore_sequence_<dataset>.txt manifest, and the matching
  service contract under <service_repo>/docs/synthetic_datasets/. Do not
  use for generic Liquibase migrations, unrelated DML edits, or when the
  user only wants to run/validate an existing profile (use
  liquibase-synthetic-scenario-validation).
---

# Liquibase synthetic dataset authoring

Create synthetic datasets that restore predictably through the Liquibase
pipeline.

## Resolve repositories

Resolve `rm_db_migrations_liquibase` and the matching service repository as
workspace siblings. Read `test_data/readme.md` and the restore
implementation as sources of truth. Do not use obsolete Flyway
`rm_db_migrations`.

## Contracts

| Owner | Path | Owns |
|---|---|---|
| Dataset | `test_data/<db_type>/dml/<dataset>/README_<dataset>_scenarios.txt` | index, restore skeleton, ranges, invariants, scenarios, verification |
| Service | `<service_repo>/docs/synthetic_datasets/<dataset>.md` | index, cwd, local config keys, run argv, staging, cleanup |

Templates: [`templates/dataset_oracle.txt.tmpl`](./templates/dataset_oracle.txt.tmpl),
[`templates/service_contract.md.tmpl`](./templates/service_contract.md.tmpl).

Keep indexes aligned (`dataset_name`, `db_name`, `service_repo`). Paths are
relative to the owning repo root, or `../sibling/...` for cross-repo
pointers. Never commit credentials.

Oracle index must include `dataset_name`, `db_name`, `db_type`, `manifest`,
`service_repo`, `service_contract`. Service index must include
`dataset_name`, `service_repo`, `dataset_oracle`, `db_name`.

`db_type` selects the Liquibase tree and `test_data/<db_type>/` root (not a
Postgres type). `PLATFORM` → `rm_platform`. Oracle `db_type`, manifest path,
and restore `--db-type` must agree.

## Workflow

1. Confirm the dataset folder and service repo. Stop if either is vague or
   ambiguous (including the same dataset name under multiple
   `test_data/<db_type>/dml/` trees). Do not infer from ambient context.
   Accept equivalent wording that clearly names the pair (e.g.
   `fill_processing` + `rm_fill_processing`).
   - Missing contract → stub from templates (index filled; TODOs elsewhere).
     Stubs are not a completed profile.
   - Existing contract → do not overwrite; expand only if the user asks.
2. Inspect schema, baseline, existing datasets, and restore tooling.
3. Define scenarios (purpose, prerequisites, action, expected outcome).
4. Design deterministic IDs and FK-safe ordering.
5. Draft fixtures, dedicated manifest, and oracle docs; put run/config only in
   the service contract. Include runnable verification SQL by default;
   narrative-only verification only if the user explicitly opts out (confirm).
6. Review proposed files with the user, then apply.
7. Verify manifest expansion, authorized local restore, invariants, and repo
   checks.

## Layout

Isolated tree: `test_data/<db_type>/dml/<dataset>/`. Fixtures:
`<table>_0001.sql` (local numbering). Manifest:
`test_data/<db_type>/dml/dml_restore_sequence_<dataset>.txt` (paths relative to
`dml/`; `#` comments; `!` exclusions; parents before dependents).

## Fixture rules

- Deterministic IDs/UUIDs in a documented non-colliding range.
- Do not duplicate baseline lookup/bootstrap/codex/user rows.
- Preseed lifecycle prerequisites only — not application outputs.
- Smallest graph that exercises the scenario; SQL `NULL` stays `NULL`.
- Sequence sync runs after DML; do not add ad hoc sequence updates.

Schema changes belong in `db/<service>/changelogs/...`, not dataset DML.

## Restore order

Newest `ddl/db_snapshot_*` → Liquibase → manifest DML →
`sequence_counter_sync`. Ignore `draft_db_snapshot_*`. Watch for an empty or
incorrectly promoted newer `db_snapshot_*`, glob pollution, and manifests
pointing outside the isolated tree. Never skip Liquibase for current-schema
validation. Get explicit authorization before drop/recreate.

## Definition of done

1. Both contracts exist with matching required index keys and resolved paths.
2. Oracle has restore skeleton, ranges, invariants, scenarios, and **executable
   verification queries** (unless user opted out).
3. Service contract has cwd, config keys, committed run, staging, cleanup
   (`none` allowed when N/A). No required TODOs left.
4. Authorized local restore + scenario validation succeed via
   `liquibase-synthetic-scenario-validation`.
5. Pre-commit / repo checks pass in every changed repository (`.py` changes:
   `source venv/bin/activate && pre-commit run --all-files`).
