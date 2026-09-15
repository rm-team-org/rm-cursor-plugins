# liquibase-synthetic-dataset-authoring

Authors isolated, deterministic synthetic datasets in
`rm_db_migrations_liquibase`, with matching service run contracts under the
consuming service repo.

**Skill file:** [SKILL.md](./SKILL.md)

## What it does

1. Resolves the dataset folder and service repository, then finds or stubs both
   contracts (dataset oracle + service run contract) from
   [`templates/`](./templates/).
2. Never overwrites an existing contract unless you explicitly ask to expand it.
3. Guides isolated fixture layout, FK-safe
   `dml_restore_sequence_<dataset>.txt` manifests, and scenario documentation.
4. Requires **executable verification queries** in the oracle by default
   (narrative-only only if you opt out during authoring).
5. Requires review before applying fixtures, then an authorized local restore
   before calling the profile complete.

## When to use

- Creating or extending an isolated dataset under
  `test_data/<db_type>/dml/<dataset>/`
- Writing or repairing its dedicated restore manifest
- Bootstrapping or updating the matching
  `<service_repo>/docs/synthetic_datasets/<dataset>.md` contract

Do **not** use for generic Liquibase migrations, unrelated DML edits, or when
you only want to restore/run/validate an existing profile — use
[`liquibase-synthetic-scenario-validation`](../liquibase-synthetic-scenario-validation/README.md)
for that.

## Related skills

- [`liquibase-synthetic-scenario-validation`](../liquibase-synthetic-scenario-validation/README.md)
  — restore, run, and validate against the oracle
