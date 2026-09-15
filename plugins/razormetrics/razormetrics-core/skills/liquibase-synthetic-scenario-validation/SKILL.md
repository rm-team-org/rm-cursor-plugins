---
name: liquibase-synthetic-scenario-validation
description: >-
  Restores isolated Liquibase synthetic datasets into dedicated local databases,
  runs the matching service, and validates every scenario against its oracle.
  Use only when the user names both the Liquibase dataset folder under
  test_data (for example fill_processing, drugs_catalog, or drugs_downstream)
  and the matching service repository (for example rm_fill_processing or
  rm_drugs_tasks). Do not use for generic Liquibase, migrations, or unrelated
  service work.
---

# Liquibase synthetic scenario validation

Restore, run, and validate one profile from repository-owned contracts. Do not
hardcode profile run bodies here.

## Scope gate

Require both:

1. Dataset folder under
   `rm_db_migrations_liquibase/test_data/<db_type>/dml/<dataset>/`
2. Matching service repository

Example pairs (not a closed allowlist; do not invent from ambient context):

| Dataset folder | Service repository |
|---|---|
| `fill_processing` | `rm_fill_processing` |
| `drugs_catalog` | `rm_drugs_tasks` |
| `drugs_downstream` | `rm_drugs_tasks` |

If either name is missing, vague, or ambiguous across `test_data` trees, stop
and ask. Do not infer. Once both are explicit, continue even if not in the
table above. Accept equivalent wording that clearly names the pair (e.g.
`drugs_catalog` + `rm_drugs_tasks`, or `fill_processing` +
`rm_fill_processing`).

Profile exists only when **both** contract files are present. Missing either →
ask whether to author via `liquibase-synthetic-dataset-authoring` (create
nothing unless the user says yes). Both present but bad indexes/paths →
validation error, not “missing profile.” Unresolvable service sibling → resolve
error (do not offer authoring yet).

## Resolve repositories

Siblings: `rm_db_migrations_liquibase`, `rm_utils`, named service repo. Use only
`rm_db_migrations_liquibase/test_data` (not Flyway `rm_db_migrations`).

## Contracts

1. Dataset oracle:
   `.../dml/<dataset>/README_<dataset>_scenarios.txt`
2. Service contract:
   `<service_repo>/docs/synthetic_datasets/<dataset>.md`

Oracle index: `dataset_name`, `db_name`, `db_type`, `manifest`, `service_repo`,
`service_contract`. Service index: `dataset_name`, `service_repo`,
`dataset_oracle`, `db_name`. Indexes must match the user-named pair.
`manifest` / `service_contract` are relative to their owning repo root;
`dataset_oracle` is sibling-relative (`../rm_db_migrations_liquibase/...`).

Ownership: restore identity/skeleton in the oracle; run/config/staging/cleanup
in the service contract. Do not re-embed either here.

## Credentials

Localhost defaults only: `postgres` / `postgres` on `localhost:5432`. Never
commit or print them. Refuse non-local targets.

## Workflow

1. Enforce scope gate; stop if service sibling missing.
2. Inspect contracts; hand off to authoring only if user confirms missing
   profile (stubs only; no overwrite; review before fixtures).
3. Read oracle, manifest, and service contract in full.
4. Expand manifest statically; stop on zero/duplicate/out-of-tree matches.
5. Get authorization to drop/recreate exact `db_name`.
6. Restore with oracle skeleton + local credentials; never `--skip-liquibase`;
   require `--db-cluster=local` and `--db-host=localhost`.
7. Inspect restore output and psql log. Stop on `Liquibase command failed`,
   missing manifest file, or failed DML/snapshot restore even if the wrapper
   exits 0. Init-script noise such as `ERROR: role "..." already exists` or
   `database "..." does not exist` alone is not failure; any `ERROR:` after
   snapshot restore begins (dump, Liquibase, DML, sequence sync) is failure.
8. Query pre-run invariants from the oracle.
9. Configure, stage, and run only from the service contract; stop on run
   failure.
10. Execute oracle **verification queries** for every scenario. Do not invent
    joins or scenario bodies. Treat `(null)` in an oracle as SQL `NULL`, not
    text. If verification SQL is absent, fail unless the oracle documents an
    explicit narrative-only opt-out. Do not hide partial failures.
11. Check sequence counters and aggregate totals when present.
12. Cleanup per service contract.

Do not repair missing baseline data or add defensive fallback rows; that is a
dataset failure.

## Report

1. Dataset, service, db, contract paths, query scope.
2. Restore stages (snapshot, Liquibase, DML, sequence sync).
3. PASS/FAIL per scenario with expected vs observed.
4. Aggregates / sequence checks; every mismatch or failure.
5. Whether temp config / staged inputs were restored or removed.

Redact credentials in commands, logs, and reports.
