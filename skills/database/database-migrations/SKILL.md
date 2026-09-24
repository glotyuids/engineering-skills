---
name: database-migrations
description: How to write, run and recover schema migrations without downtime or a stuck deploy — file naming and the up/down pair, one logical change per migration, forward-only in production, statements written so a partial re-run is safe, the JSONB null/scalar trap, lock-avoidance on large tables (concurrent indexes, nullable column then batched backfill then constraint), expand/contract for renames during a rolling deploy, migrations as a pre-upgrade hook Job, and the recovery procedure when a migration job times out and leaves the version tracker dirty. Use when the user says "add a migration", "write the up/down SQL", "alter this table", "add a column/index/constraint", "rename a column", "backfill this data", "the migration job timed out", "migrations are dirty", "schema_migrations is stuck", "the deploy is blocked on migrations", "how do I roll back a migration", "this migration locked the table", "create a role in a migration", "the policy fails on re-run", or when reviewing a migration before it ships.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.2
---

# Database migrations

Schema change is the one deploy step that is not idempotent by default, not instantly
reversible, and able to take the whole service down while looking like a green pipeline.
This skill is the discipline that makes it boring.

Items marked `[!]` caused a real production incident when missed. They are not style
preferences.

## Scope

This skill defines only: **how a migration file is named and structured, what may go in one,
how statements are written so they survive a partial re-run, how to change a large or hot
table without blocking it, how a rename is staged across a rolling deploy, how migrations are
executed at deploy time, and how to recover a stuck or dirty migration state.**

It does not define: schema design, indexing strategy, query shape or runtime concurrency —
those belong to `postgres-patterns` in this pack. It does not define the deploy pipeline or
the chart that carries the migration Job: if a `kubernetes-helm`, `cicd-build-deploy` or
`terraform-conventions` skill is installed, follow it for that layer; otherwise follow the
project's own conventions. Examples are PostgreSQL; the naming, re-runnability, lock and
recovery rules hold for any SQL store with a version-tracking migration tool.

## 1. File naming and the up/down pair

```
migrations/
├── 000001_create_<entity>_table.up.sql
├── 000001_create_<entity>_table.down.sql
├── 000002_add_<column>_to_<entity>.up.sql
└── 000002_add_<column>_to_<entity>.down.sql
```

| Rule | Why |
|---|---|
| Zero-padded sequential prefix, `snake_case` description of the *change*, not the ticket | sorts lexicographically = applies in order; readable in a directory listing |
| Every `.up.sql` has a matching `.down.sql` | the pair is the review artefact — writing the down forces you to think about reversibility |
| One logical change per migration | a failure names itself, and a partial apply has a small blast radius |
| Plain SQL, no application code, no business logic | a migration must be replayable years later, when the code that would have run it is gone |
| Live in the service that owns the schema, shipped in the same image as that service | tool and files can never be a version apart |

- **Never edit a migration that has been applied anywhere** — not in production, not on a
  colleague's machine. The tool records versions, not content; editing an applied file makes
  two databases claim the same version with different schemas. Fix forward with a new file.
- **Numbering collides across branches.** Two branches both take the next number; whichever
  merges second must renumber *before* merge — never after the file has been applied
  anywhere. Timestamp prefixes avoid the collision at the cost of unreadable ordering; pick
  one convention repo-wide and state it in the project delta.
- **A lower number merged later is silently skipped.** Version-table tools only ever apply
  the next version *above* the database's current one, so a branch that took `000004` and
  merges after `000005` is already applied leaves every existing database without
  `000004` — no error, no dirty flag. Parallel branches therefore take the next *free*
  number at merge time, never a number reserved in advance and never a private range. And
  a database sitting on a version whose file was renamed or removed applies nothing at
  all, again without an error.
- `[!]` **If a table is user-owned and the project isolates rows per user, the row-level
  security enablement and its policy ship in the same migration that creates the table**,
  never as a follow-up — a table that exists for even one deploy without its policy is a
  table that served somebody else's rows. The policy content itself belongs to
  `postgres-patterns`.

## 2. Forward-only in production

A down migration is a **development convenience**, not a rollback strategy.

- Down migrations exist so you can iterate locally and so CI can prove `up → down → up`
  round-trips on a scratch database. That test is their real value.
- In production you **roll forward**: the fix for a bad migration is migration N+1.
- The reason is data, not SQL. `DROP COLUMN` in a down migration is not an undo — the
  column's data is gone. A down migration that silently destroys data is worse than no down
  migration at all: write it, but say what it loses in a comment.
- When a change is genuinely irreversible (destructive backfill, type narrowing, dropping a
  table), the `.down.sql` says so explicitly rather than pretending:

```sql
-- Irreversible: the pre-migration value of <column> is not recoverable.
-- Restore from backup if this must be undone.
SELECT 1;
```

- Corollary: the *deploy* rollback path is the previous application image running against
  the new schema. That only works if every migration is backward-compatible with the code
  one version behind — which is what §6 (expand/contract) buys you.

## 3. `[!]` Write every statement so a partial re-run is safe

A migration will be re-run. The job times out, the hook retries, an operator re-applies after
a dirty state — assume it, do not hope.

- Idempotent DDL everywhere it exists: `CREATE TABLE IF NOT EXISTS`,
  `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`,
  `DROP ... IF EXISTS`.
- For DDL with no `IF NOT EXISTS` form (constraints, in older engines), guard it:

```sql
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = '<entity>_<column>_fk'
    ) THEN
        ALTER TABLE <entity>
            ADD CONSTRAINT <entity>_<column>_fk
            FOREIGN KEY (<column>) REFERENCES <other>(id) NOT VALID;
    END IF;
END $$;
```

- Row-security policies have **no** `IF NOT EXISTS` form in any PostgreSQL release. Make
  the pair re-runnable by dropping first — both statements run inside the migration's
  transaction, so no reader ever sees the table without its policy:

```sql
DROP POLICY IF EXISTS <table>_owner_isolation ON <table>;
CREATE POLICY <table>_owner_isolation ON <table>
    USING      (owner_id = NULLIF(current_setting('app.owner_id', true), '')::uuid)
    WITH CHECK (owner_id = NULLIF(current_setting('app.owner_id', true), '')::uuid);
```

  The policy's content belongs to `postgres-patterns`; the drop-then-create shape is what
  survives a re-run. Roles need the same care (§7).
- **Backfill `UPDATE`s must be safe to re-run.** Constrain them to rows that still need the
  change, so a second run is a no-op instead of a double application:

```sql
-- Re-runnable: only touches rows not yet migrated.
UPDATE <entity>
   SET <new_column> = <expression>
 WHERE <new_column> IS NULL;
```

  Never write a backfill whose effect compounds (`SET counter = counter + 1`,
  `SET text = text || ' suffix'`) without a guard that excludes already-migrated rows.
- Prefer one statement per concern, each independently safe, over a long script whose
  correctness depends on reaching the end.
- Seed/reference data: `INSERT ... ON CONFLICT DO NOTHING` (or `DO UPDATE` when the row is
  meant to be reconciled), never a bare `INSERT`.

## 4. `[!]` The JSONB null/scalar trap

Set-returning and element-wise JSONB functions assume the column holds the shape you expect.
On a `NULL` or a scalar value they error, and the migration dies mid-way — which is how a
version tracker ends up dirty (§8).

```sql
-- BAD: errors on NULL, and on any row where the column is not an array
SELECT jsonb_array_elements_text(some_jsonb_column) FROM <entity>;
```

```sql
-- GOOD: normalise the shape first, then expand
SELECT jsonb_array_elements_text(
           CASE WHEN jsonb_typeof(some_jsonb_column) = 'array'
                THEN some_jsonb_column
                ELSE '[]'::jsonb
           END
       )
  FROM <entity>;
```

The same guard applies to `jsonb_each`, `jsonb_object_keys`, `jsonb_array_length` and to `->>`
chains that assume a nested object. Rules:

- Type-check with `jsonb_typeof(col) = '<expected>'` before expanding, and supply the empty
  value of that type as the fallback.
- Remember SQL `NULL` and JSON `'null'::jsonb` are different failures; `COALESCE(col, '[]'::jsonb)`
  handles only the first.
- A migration that touches JSONB must be tested against a row set containing: the expected
  shape, `NULL`, `'null'::jsonb`, a scalar, and an empty array. Production has all five.

## 5. Changing a large or hot table without blocking it

The danger is not duration, it is the lock. In PostgreSQL an `ACCESS EXCLUSIVE` lock request
that has to wait **queues in front of every later reader** — one blocked `ALTER TABLE` stalls
all traffic on that table, not just writes. So: acquire strong locks briefly or not at all.

| Operation | Lock / cost | Safe form |
|---|---|---|
| Add nullable column, no default | brief `ACCESS EXCLUSIVE`, metadata only | safe as written |
| Add column with a **constant** default | metadata only on modern engines; **full table rewrite** on old ones | verify the engine version; otherwise add nullable, backfill, then set the default |
| Add column with a **volatile** default (`now()`, `gen_random_uuid()`) | full rewrite, always | add nullable → backfill in batches → set the default for new rows |
| `SET NOT NULL` | full table scan while holding a strong lock | add `CHECK (col IS NOT NULL) NOT VALID` → `VALIDATE CONSTRAINT` (weak lock) → `SET NOT NULL` (skips the scan when a valid check exists) |
| Add foreign key | scans and locks both tables | `ADD CONSTRAINT ... NOT VALID` → later `VALIDATE CONSTRAINT` |
| Create index | blocks writes for the whole build | `CREATE INDEX CONCURRENTLY` (see below) |
| Drop index | brief strong lock | `DROP INDEX CONCURRENTLY` on a hot table |
| Change column type | full rewrite | new column → backfill → expand/contract swap (§6) |
| Rename column or table | metadata only, but **breaks running code instantly** | expand/contract (§6) |
| Drop column | metadata only | only after no deployed version references it (§6) |
| `UPDATE` over the whole table | long transaction, bloat, replication lag | batch (below) |

**Concurrent index creation.**

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_<entity>_<column>
    ON <entity> (<column>);
```

- `CONCURRENTLY` **cannot run inside a transaction block**. Most tools wrap each migration in
  one, so this statement must live in its own migration file, marked with whatever the tool
  uses to disable the wrapper. Getting this wrong fails immediately and loudly — good.
- `[!]` A failed or interrupted concurrent build **leaves an invalid index behind**. It is not
  used by the planner but is maintained on every write, and the re-run's
  `IF NOT EXISTS` sees it and skips. Recovery is to `DROP INDEX CONCURRENTLY` the invalid
  index and re-create it. Check for leftovers with `pg_index.indisvalid = false` after any
  migration failure that involved an index build.

**Batched backfill.** Never one `UPDATE` over millions of rows: it holds a transaction open,
bloats the table, and can stall replicas.

```sql
-- Run repeatedly until zero rows are affected; each batch commits on its own.
UPDATE <entity>
   SET <new_column> = <expression>
 WHERE id IN (
       SELECT id FROM <entity>
        WHERE <new_column> IS NULL
        ORDER BY id
        LIMIT 5000
       );
```

Drive the loop from the migration tool, a one-off job, or the application — whatever the
project uses — but keep each batch a separate transaction, keep the predicate on an indexed
column, and make the loop resumable (it is, because the `IS NULL` predicate is the progress
marker). A backfill of any size is a *separate* migration from the DDL that precedes it.

**Fail fast instead of queueing.** Set a short lock timeout at the top of any migration that
touches a hot table, so a blocked `ALTER` gives up instead of parking the lock queue:

```sql
SET lock_timeout = '3s';
SET statement_timeout = '0';   -- explicit: the migration itself may be slow
```

A migration that fails on `lock_timeout` is retried at a quieter moment. A migration that
waits takes the site down.

## 6. Expand/contract, so old and new code run at once

During a rolling deploy both the old and the new application version are serving traffic
against **one** schema. Any change that is not backward-compatible breaks the old pods; any
change that is not forward-compatible breaks the new ones during a rollback. A rename is
therefore never one migration. Renaming `<old_column>` to `<new_column>`:

| Phase | Migration | Code deployed with it |
|---|---|---|
| 1. Expand | add `<new_column>` (nullable, no volatile default) | — |
| 2. Dual-write | — | code writes **both** columns, reads `<old_column>` |
| 3. Backfill | batched backfill of `<new_column>` from `<old_column>` (§5) | — |
| 4. Switch reads | — | code reads `<new_column>`, still writes both |
| 5. Stop writing the old | — | code writes only `<new_column>` |
| 6. Contract | drop `<old_column>` | — |

- Each phase is its own deploy. Phases 1 and 6 must be separated by **at least one full
  release cycle** — the contract step is only safe once no deployed or rollback-able version
  references the old column.
- The same shape covers: type changes (new column, dual-write, swap, drop), table splits
  (write to both, migrate readers, drop), and moving a column between tables.
- A database view over the old name can substitute for phase 2 in read-heavy cases, but a
  view does not make writes work — dual-write in code is the general answer.
- `[!]` Never combine "drop the old" with "add the new" in one migration on a
  rolling-deployed service. The gap between the migration hook finishing and the last old pod
  terminating is where the errors happen, and it is invisible in staging with one replica.
- If the project uses a strict deploy freeze and can take downtime, say so explicitly and do
  the simple rename — but write down that the service was stopped. Do not claim zero-downtime
  for a change that was not.

## 7. Running migrations at deploy time

Migrations run as a **pre-install/pre-upgrade hook Job**, before the new application pods
start, using the **same image as the service** so the tool and the files ship together. Gate
the template on a flag (`migrations.enabled`) so a first install can be staged. If a
`kubernetes-helm` skill is installed, it owns the template detail; the rules that belong to
the migration itself:

- `[!]` **The target database must exist before the job runs.** Provisioning (the
  MANAGED_PG database, its user and grants) is a separate, earlier step in the deploy
  sequence — infrastructure apply, then secret sync, then migrate, then deploy. A migration
  job pointed at a database that was never created fails in a way that looks like a
  connectivity problem and sends everyone to the wrong place. Order the pipeline explicitly.
- `[!]` **The hook runs inside the release timeout.** The default (commonly 5 minutes) covers
  the hook *and* the rollout. A migration with a backfill exceeds it, the release fails, and
  the tracker is left dirty (§8). Either raise the timeout deliberately for that release, or —
  better — move the backfill out of the hook into a resumable job (§5).
- On a **fresh** install the secret carrying the DSN may not have synced when the hook fires;
  install once with migrations disabled, then upgrade with them enabled. This is a deploy
  concern, covered by the infra pack if installed.
- The job's database driver may differ from the application's, and TLS requirements differ
  with it: a DSN naming a CA file on disk needs that file mounted for the app, while the
  migration tool's driver is often satisfied without it. Migrations then succeed while the
  service crash-loops — do not read a green migration job as "the database is reachable by
  the app".
- Only one migrator at a time. Serious tools take an advisory lock; verify yours does before
  allowing parallel deploys of services that share a database.
- The job must be a **Job**, not an init container on the Deployment: an init container runs
  once per pod, so N replicas race, and it re-runs on every restart.

### A service that migrates itself

A daemon with no orchestrator — a single binary under an init system — migrates on start,
before it serves. What changes:

- **Two roles.** The migration runs as a *migration owner* that holds DDL rights and owns
  the tables; the service then serves as the *application role*, which holds only DML on
  those tables and is not their owner. One role for both makes every row-security policy
  decorative unless it is `FORCE`d, and hands a compromised request path `DROP TABLE`.
- **Readiness reads the version table.** Grant the application role `SELECT` on the
  tracker (`schema_migrations` or the tool's equivalent) so the readiness check can assert
  that the applied version equals the latest embedded migration and the dirty flag is
  clear. Not ready until that holds; a failed migration keeps the process not ready — it
  does not serve on a stale schema.
- **One migrator at a time still applies.** Two instances starting together contend; the
  tool's per-database advisory lock serialises them, and the loser finds the version
  already advanced and does nothing. Verify your tool takes that lock before running two
  instances against one database.
- **The same files, embedded.** The migrations ship inside the binary, so the code and the
  schema it expects are one artefact; rolling back to the previous binary needs the
  previous schema to still be compatible (§6), exactly as with a hook Job.

### Cluster-wide objects: roles

A role belongs to the cluster, not to the database the migration runs in. Two
consequences:

- **Default: provision roles with the database, not in migrations.** The application role,
  the migrator role and any maintenance role are created in the same earlier step that
  creates the database and its grants (first rule above) — by the infrastructure layer,
  where a `terraform-conventions` skill applies if installed. A migration then only
  `GRANT`s on the objects it created.
- **When a per-database migration must create a role** — a single-database deployment, a
  local test cluster — it needs the `CREATEROLE` privilege, it must survive a concurrent
  creator, and its `down` never drops the role, because another database may already
  depend on it:

```sql
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '<app_role>') THEN
        CREATE ROLE <app_role> NOLOGIN;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;   -- created by another migrator between the check and the CREATE
END $$;
```

  The exception handler is the real guard; the existence check only narrows the race. Do
  not rely on the migration tool's advisory lock here — **advisory locks are local to one
  database**, so migrators for two databases on the same cluster never see each other's
  lock. If two such migrators must be serialised, take an explicit `pg_advisory_xact_lock`
  in a database both connect to, or run them one after the other in the pipeline.

## 8. Recovery: the migration job timed out and the state is dirty

Version-table tools (the `schema_migrations` version-plus-`dirty`-flag family) mark the
version dirty when a run dies mid-migration, and **every later run refuses to start** until
the flag is cleared. This is the single most common migration incident. Work the sequence;
do not start by forcing a version.

1. **Stop the retry loop.** Disable the migration hook (or suspend/delete the failed Job) so
   retries stop re-acquiring locks while you are diagnosing. Note the failing version.
2. **Read the actual error** from the job's logs before touching anything. Lock timeout,
   statement timeout, a JSONB type error (§4), a missing database (§7) and an out-of-disk
   condition all present as "the migration failed" and have different fixes.
3. **Inspect the tracker.** From a one-off session with the same DSN, read the version table:
   the current version and whether it is dirty. Ledger-style tools instead list applied
   migrations with checksums — read the last row and its status.
4. **Determine what actually applied.** Do not assume. Open the failing migration and check
   each object against the catalogue: does the column exist, does the constraint exist, is the
   index present *and valid* (`indisvalid`), how many rows still match the backfill's
   `WHERE`. DDL is transactional in PostgreSQL, so a single-transaction migration usually
   rolled back cleanly — but a migration containing `CREATE INDEX CONCURRENTLY`, a batched
   backfill, or several statements the tool did not wrap can be **half applied**.
5. **Decide the target version:**

   | Finding | Action |
   |---|---|
   | Nothing applied | force the tracker to the **previous** version, re-run |
   | Everything applied, only the bookkeeping failed | force the tracker to **this** version, do not re-run |
   | Partially applied | clean up the specific artefacts (drop the invalid index, revert the half-written rows), make the statements re-runnable if they were not (§3), force to the **previous** version, re-run |

6. **Force the version.** Use the same tool, same version, same migration files, from a
   one-off environment that has the DSN — a short-lived pod, a bastion session, or a local
   shell with a tunnel. `force` only rewrites the tracker; **it applies and reverts nothing**,
   which is exactly why step 4 must come first. If the tool has no force command, update the
   version row by hand inside an explicit transaction, with a `WHERE` on the version you
   expect, and check the affected row count before committing.
7. **Re-run and verify:** the dirty flag is clear, the version is the expected one, every
   object the migration was supposed to create exists, the backfill's `WHERE` matches zero
   rows, and the application starts and answers its readiness check.
8. **Fix the cause, not just the state.** Raise the release timeout, split the migration, move
   the backfill out of the hook, or add the missing guard. A dirty state that was forced and
   forgotten recurs on the next deploy. If an `incident-response` skill is installed, record
   it there; otherwise note it in the project's known-issues document.

Never: force a version you have not verified against the catalogue; force forward to skip a
migration that "probably worked"; `DROP` and re-create the tracker table; or run the recovery
from a developer machine against production without recording what was done.

## 9. Review checklist

- [ ] One logical change; `.up.sql` and `.down.sql` both present; no application logic.
- [ ] Filename number does not collide with another branch's; nothing already-applied edited.
- [ ] Every statement idempotent or explicitly guarded; the backfill is re-runnable and its
      predicate excludes already-migrated rows.
- [ ] JSONB access type-checked against `NULL`, `'null'`, scalar and empty-array rows.
- [ ] Large/hot tables: no rewrite, no long-held strong lock; indexes built concurrently in
      their own migration; constraints added `NOT VALID` then validated; `lock_timeout` set.
- [ ] Backward-compatible with the currently deployed code; renames staged expand/contract;
      no add-and-drop in the same migration.
- [ ] Timed against production-sized data, not an empty scratch database — and against the
      deploy timeout it has to fit in.
- [ ] `up → down → up` proven on a scratch database in CI.
- [ ] The down migration's data loss, if any, is stated in a comment.
- [ ] Policies are drop-then-create; any role creation carries the duplicate-object guard,
      and no `down` drops a role.
- [ ] Parallel-branch migrations took the next free number at merge; nothing numbered below
      an already-applied version was added.

## Project delta

The consuming repo supplies:

- The migration tool and its version, whether it wraps each migration in a transaction, and
  how that wrapper is disabled for `CONCURRENTLY` statements.
- Numbering convention (sequential vs timestamp) and the collision-resolution rule.
- Where migrations live per service, and how they reach the runtime image.
- The tracker's shape (version-plus-dirty table vs applied-ledger) and the exact command that
  forces a version.
- How a one-off session with the production DSN is obtained, and who is allowed to run one.
- The deploy sequence position of migrations, the release timeout, and the flag that gates
  the migration Job.
- Batch size and pacing for backfills, and where the loop is driven from.
- Whether tables are owner-scoped (per user, tenant or organisation) and require a
  row-security block in the creating migration.
- Whether roles are provisioned by infrastructure or by a migration, and the migrator's
  privileges (`CREATEROLE` or not).
- Whether the service migrates itself on start, the migration-owner and application roles,
  and the tracker grant the readiness check relies on.
- The environments a migration must pass through before production.
