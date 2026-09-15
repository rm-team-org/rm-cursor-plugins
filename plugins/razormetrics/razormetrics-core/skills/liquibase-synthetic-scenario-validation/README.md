# liquibase-synthetic-scenario-validation

Restores an isolated Liquibase synthetic dataset into a dedicated local
database, runs the matching service, and validates every scenario against its
oracle.

**Skill file:** [SKILL.md](./SKILL.md)

## What it does

1. Requires you to name **both** the Liquibase dataset folder and the matching
   service repository (stops and asks if either is vague).
2. Discovers repository-owned contracts for that pair:
   - dataset oracle under `rm_db_migrations_liquibase/test_data/...`
   - service run contract under `<service_repo>/docs/synthetic_datasets/`
3. Restores via `rm-db-create-synthetic-dataset.sh` (localhost only), then
   configures, runs, and cleans up only as specified by the service contract.
4. Executes the oracle’s verification queries (PASS/FAIL per scenario) and
   reports aggregates / failures.
5. If either contract is missing, offers to hand off to
   [`liquibase-synthetic-dataset-authoring`](../liquibase-synthetic-dataset-authoring/README.md)
   instead of inventing fixtures.

## When to use

Only when you name both:

- a dataset folder under `test_data` (e.g. `fill_processing`, `drugs_catalog`,
  `drugs_downstream`)
- the matching service repository (e.g. `rm_fill_processing`, `rm_drugs_tasks`)

Do **not** use for generic Liquibase, migrations, or unrelated service work.

## Related skills

- [`liquibase-synthetic-dataset-authoring`](../liquibase-synthetic-dataset-authoring/README.md)
  — create or extend the dataset + contracts when the profile does not exist yet
