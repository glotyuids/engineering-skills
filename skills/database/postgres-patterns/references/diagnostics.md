# PostgreSQL diagnostics

Companion to the `postgres-patterns` skill (§8). Run these from a **read-only** session.
`pg_stat_statements` must be enabled on the instance — on MANAGED_PG that is usually an
instance setting, not a superuser `CREATE EXTENSION` you can run yourself.

## Slowest statements, biggest tables, unused indexes

```sql
-- slowest by average time; swap to total_exec_time for "where does the load go"
SELECT calls, mean_exec_time, total_exec_time, rows, query
FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;

-- table sizes, heap plus indexes plus TOAST
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS total
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 20;

-- indexes that are never scanned: dead weight on every write
SELECT relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes ORDER BY idx_scan, pg_relation_size(indexrelid) DESC LIMIT 20;

-- tables taking sequential scans they should not
SELECT relname, seq_scan, seq_tup_read, idx_scan, n_live_tup
FROM pg_stat_user_tables WHERE seq_scan > 0 ORDER BY seq_tup_read DESC LIMIT 20;
```

## Live problems: long transactions, blocking, connection budget, autovacuum debt

```sql
-- transactions open too long (they block VACUUM and hold locks)
SELECT pid, state, now() - xact_start AS open_for, left(query, 120) AS query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL AND now() - xact_start > interval '1 minute'
ORDER BY open_for DESC;

-- who is blocking whom
SELECT pid, pg_blocking_pids(pid) AS blocked_by, wait_event_type, left(query, 120)
FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0;

-- connection budget, per client application and state
SELECT application_name, state, count(*)
FROM pg_stat_activity GROUP BY 1, 2 ORDER BY 3 DESC;

-- dead tuples and when autovacuum last ran
SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 20;
```

Then take the offending statement and run `EXPLAIN (ANALYZE, BUFFERS)` on it with
production-like parameters. Read the plan bottom-up; compare estimated versus actual rows at
each node. §4 of the skill says which queries earn that check before they ship.
