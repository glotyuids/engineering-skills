---
name: integration-testing
description: Integration and end-to-end tests that run against a real deployed environment, safely — the explicit opt-in gate, a dedicated least-privilege test identity whose credentials come from the secret manager, self-created test data with registered cleanup, marker values so orphans stay sweepable, keeping the suite out of the default unit-test path, an error→cause→fix triage table, and ephemeral test-owned dependencies that run ungated and fail rather than skip. Use when asked to run integration tests, add a smoke test against staging or production, verify a deployed service end to end, wire a CI job that talks to a shared environment, or troubleshoot 401/403, timeout and leftover-data failures in tests. Trigger phrases: "run the integration tests", "smoke test prod", "test against staging", "how do I get a token for the test", "why is my test getting 403", "the test left junk behind", "clean up the test data", "the tests need Postgres", "should the DB tests skip when Postgres is missing".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.1
---

# Integration testing against a real environment

**Core rule: a test that touches a shared environment is opt-in by an explicit
environment variable, creates every object it touches, and removes them again. Anything
short of that is a scheduled outage waiting for a maintenance window.**

**A test that mutates shared state without cleanup will eventually be run against
production by someone who did not read this file.** Suites get copied into CI, wired into
a `make test` alias, or run by a new contributor with a stale shell. The gate and the
cleanup are what make running tests against a real environment acceptable at all —
neither is optional, and neither can be replaced by a comment saying "careful".

This skill defines only how tests against a *real deployed* system are gated,
authenticated, isolated, cleaned up and triaged — and, in section 11, how ephemeral
dependencies a test binary starts for itself run on the default path without any of that
machinery. It does not define unit tests, in-process fakes, contract/consumer-driven tests,
or load testing. It is language-neutral: where a code shape is unavoidable it is shown as
a labelled illustration in one language, with the equivalent named for other ecosystems.
If the `ui-test-playwright` skill is installed, it covers the browser layer's own
mechanics; the gate, the credentials and the cleanup rules below still apply to it.

## 1. The four invariants

| Invariant | Mechanism | What it prevents |
|---|---|---|
| **Opt-in** | A dedicated environment variable must be set to an exact value, or every test in the suite skips | An unattended or accidental run against a shared environment |
| **Separation** | A build tag, tag filter, or separate directory keeps the suite out of the default test command | `make test` on a laptop or in a PR pipeline reaching the network |
| **Isolation** | Every test creates the data it needs and touches nothing pre-existing | Corrupting real users' data; order-dependent, mutually interfering tests |
| **Reversibility** | Cleanup is registered at creation time and runs even when the test fails | Orphaned records accumulating until someone has to clean them by hand |

All four hold together or none of them helps. A gated suite with no cleanup still leaves
debris; a clean suite with no gate still runs where it should not.

## 2. The safety gate

Pick one variable name, use it in every test, and make it the first thing every test does.

- **Exact-value match, not truthiness.** `<GATE_VAR>=1` (or `=yes`, or the literal name
  of the environment). A variable that is merely *present* gets set by accident far more
  easily than one that must equal a specific string.
- **Skip, do not fail.** A missing gate means "not requested", which is the normal state
  on a developer machine and in the default pipeline. Failing there teaches people to
  disable the suite. This applies to the *shared-environment* gate only: a dependency the
  test binary starts itself is never gated and never skips (section 11).
- **State the reason in the skip message** — name the variable, so a confused reader gets
  the answer from the test output instead of from the source.
- **Never default it on.** Not in a Makefile, not in a shell profile, not in a
  `.envrc`/direnv file, not in a devcontainer, not in a CI job's global `env:` block.
  A gate with a default is not a gate.
- **Name the environment explicitly.** The target environment is an argument or a second
  variable (`<ENV_VAR>=staging`), never inferred from the current shell context, the
  current cluster context, or "whatever the base URL happens to point at".
- **One gate per blast radius.** If the project has both a throwaway environment and a
  production one, the production gate is a *different* variable with a more deliberate
  value. Do not let one export unlock both.
- **Verify the target before mutating.** The first request of a mutating suite should
  confirm which environment answered (a version/health endpoint, the token issuer, the
  base URL echoed in the log) and abort on a mismatch.

Illustration — the skip guard, at the top of every test in the suite:

```go
// Illustration (Go) — no language is implied. Any ecosystem's skip primitive works
// the same way: pytest.skip(...) / test.skip() / Assumptions.assumeTrue(...) / skip.
if os.Getenv("<GATE_VAR>") != "1" {
    t.Skip("<GATE_VAR> != 1 — integration tests run only against an explicitly named environment")
}
```

## 3. Separation from the unit-test path

The default test command must never open a socket to a shared environment. Enforce it
mechanically, not by convention:

| Ecosystem | Mechanism (example) |
|---|---|
| Go | `//go:build integration` plus `go test -tags integration ./...` |
| Python | a marker (`@pytest.mark.integration`) with `addopts = -m "not integration"` by default |
| JS/TS | a separate project/config or file suffix the default runner does not glob |
| JVM | a separate source set or tag filter in the build tool |
| Any | a separate top-level directory the default command does not reach |

Rules that hold regardless of the mechanism:

- Integration tests live in their own directory (`tests/integration/` or equivalent), not
  interleaved with unit tests.
- The default target (`make test`) runs unit tests and tests against ephemeral, test-owned
  dependencies (section 11) — offline in the sense that it opens no socket to anything it
  did not start itself, and with no credentials available. If it needs a shared
  environment to pass, the separation has already failed.
- Integration targets are named for what they do — `make test-integration`,
  `make test-smoke` — and each one prints the environment it is about to touch before it
  starts. If the `makefile-conventions` skill is installed, follow its target-naming and
  `.PHONY` rules; otherwise follow the project's own build conventions.
- Two mechanisms are not better than one. Pick the tag *or* the directory as the
  authoritative filter and keep the other as documentation.

## 4. Credentials

The suite authenticates as a **dedicated machine identity**, never as a human's account
and never as an admin.

1. **Least privilege.** The test identity holds exactly the roles the suite needs and
   nothing more. It must not be able to delete other principals' data, change
   configuration, or read anything the suite does not assert on.
2. **Values come from SECRET_MANAGER at run time**, fetched into the shell immediately
   before the run. Never a literal in a test file, a fixture, a Makefile, a committed
   `.env`, a README, or a CI variable pasted by hand. If the `secrets-management` skill is
   installed, the test client secret is an ordinary entry under its contract; otherwise
   follow the project's own secret-handling rules.
3. **Never print the credential.** Not on failure, not at debug level, not truncated. Log
   the *key name* and whether it was set. Token bodies are credentials too — do not dump
   them into test output or CI logs.
4. **Fail fast and precisely when configuration is missing.** One helper validates all
   required variables and reports every missing name at once, before the first request.
5. **Server-side authorization is the real enforcement.** The suite's discipline is a
   convention; the service's ownership/permission check is the control. Both must exist —
   a `403 not-owner` from the API on a mis-scoped test is the system working correctly,
   not an obstacle to route around by widening the test identity's roles.
6. **Rotation is normal.** A `401` from the token endpoint usually means the secret was
   rotated, not that the test is broken. Re-fetch and re-run before investigating further.

### The shared auth helper

One helper package, used by every test, owning all of:

- reading and validating configuration from the environment (single error listing every
  missing variable);
- acquiring a token from the identity provider (a client-credentials style grant for a
  machine identity);
- caching the token for the process and refreshing it before expiry, so a long suite does
  not die halfway through;
- returning a pre-configured HTTP client that injects the authorization header and applies
  the suite's default timeout;
- exposing a way to obtain a raw token for manual debugging (`make test-token`), printing
  only what the operator needs.

Illustration — fetching the secret and running one suite:

```sh
export <TOKEN_URL_VAR>=https://example.com/oauth/token
export <CLIENT_ID_VAR>=<project>-testing
export <CLIENT_SECRET_VAR>="$(<secret-manager-cli> get --name <project>/<idp-entry> \
  --key testing-client-secret)"
export <GATE_VAR>=1

make test-smoke
```

The concrete secret-manager command is vendor-specific; the project delta names it. The
export block belongs in the runbook, not in a shell profile — see the gate rules above.

## 5. Data discipline

**Every test creates what it needs and destroys what it created. It never reads, updates
or deletes anything it did not create.**

- **Register cleanup at the moment of creation**, in the same block, before the first
  assertion — `t.Cleanup`, `defer`, a fixture teardown, an `after` hook. Cleanup written
  at the end of the test body does not run when an assertion fails in the middle, which
  is precisely when debris is created.
- **Cleanup must be idempotent and failure-tolerant.** Deleting something already gone is
  a success. A cleanup step must not panic, must not abort the remaining cleanup steps,
  and must log what it could not remove.
- **Cleanup failures are reported, not swallowed.** A test that passes while leaving an
  object behind is a failing test in slow motion. Surface it in the output and, if the
  suite is scheduled, in the alert.
- **Delete in reverse creation order** so foreign-key and ownership constraints do not
  block the teardown.
- **No fixed sleeps.** Wait for the state you need by polling with a deadline and a clear
  timeout message naming what never arrived.
- **Never assert against pre-existing data.** "The first item in the list belongs to us"
  is true until someone else uses the environment. Look up your own object by the id you
  received at creation.
- **Assume concurrency.** Two runs may overlap. Every created object carries a unique
  per-run suffix, and no test depends on a global count, an ordering, or a singleton name.
- **Read-only probes are still gated.** They are safer, not free: they consume quota, they
  appear in production analytics, and they can trip rate limits or anomaly detection.

### Marker convention

Every record a test creates carries a marker in a human-visible field, so an orphan is
identifiable by anyone who finds it and sweepable by a script.

| Element | Rule | Example |
|---|---|---|
| Prefix | A fixed, unmistakable literal in a searchable field | `__integration_test__` |
| Run id | A unique per-run token so concurrent runs never collide | `__integration_test__<runid>` |
| Suite/case | Optional, aids triage of an orphan | `__integration_test__<suite>_<runid>` |
| Ownership | Everything is created by the test identity, so a sweep can filter on both marker *and* owner | — |

Ship a **sweeper** (`make test-sweep`): deletes objects that match the marker, are owned by
the test identity, and are older than a threshold. It is the safety net for crashed runs,
killed CI jobs and network failures mid-test — not a substitute for per-test cleanup. Run
it on a schedule and after any aborted run. It must refuse to run without the gate and
must print what it would delete before deleting.

## 6. Writing a new integration test

1. **Justify the layer.** Can a unit test or a test against an ephemeral environment prove
   this? If yes, write that instead (sections 9 and 11).
2. **Place it** in the integration directory, with the project's separation mechanism
   applied (section 3).
3. **Guard it** with the gate check as the first statement (section 2).
4. **Configure it** through the shared auth helper — never re-implement token acquisition.
5. **Create your own data** in setup and register cleanup immediately (section 5).
6. **Assert on contract invariants**, not on live content (section 7).
7. **Bound it in time** — an explicit per-test deadline, plus a suite-level timeout larger
   than the slowest legitimate path.
8. **Run it twice in a row** against the environment. A test that only passes on a clean
   slate is not isolated. Then run it concurrently with itself if the suite may parallelize.
9. **Verify it left nothing.** Search for the marker after the run; the result must be
   empty.
10. **Document the run command** in the project's runbook, including the exact export
    block — `documentation-standards` defines where runbooks live.

## 7. What to assert

- **Contract invariants, not live values.** Status codes, response shape, required fields,
  state transitions, authorization outcomes, idempotency of a repeated call. Not "the
  catalogue has 42 entries".
- **No golden snapshots of production content.** It changes without warning and the test
  becomes a change-detector for other people's work.
- **Assert the negative cases too** — that an unauthenticated call is rejected, that the
  test identity cannot touch another principal's object, that a malformed request fails
  cleanly. These are the assertions that catch a broken authorization deployment.
- **For asynchronous pipelines**, assert the terminal state with a polling deadline, and
  on timeout report the last observed state and the correlation id so the failure is
  triageable from the log alone.
- **Propagate a correlation/request id** from the test into every call and print it on
  failure. Without it, matching a failed assertion to server logs is guesswork.
- Prefer a few deep flows over many shallow pokes. Integration tests are expensive; their
  value is in wiring — authentication, network policy, migrations applied, configuration
  actually loaded, cross-service contracts — not in re-testing business logic that unit
  tests already cover.

## 8. Failure triage

| Symptom | Cause | Fix |
|---|---|---|
| Every test skipped | Gate variable unset in this shell | Export it. A skip is correct behaviour, not a bug |
| `missing required env vars` | Configuration not exported, or exported in a different shell | Re-run the export block from the runbook |
| `401` on the token endpoint | Wrong or rotated client secret | Re-fetch from SECRET_MANAGER; confirm the right environment's entry |
| `401` on API calls after a token was obtained | Audience/issuer mismatch, or clock skew between client and IdP | Compare the token's audience and issuer with what the API validates; check the machine clock |
| `401` partway through a long run | Token expired mid-suite | Refresh in the helper before expiry instead of fetching once |
| `403` on every API call | Token lacks the required role or scope | Grant the least-privilege role to the test identity in the IdP and re-mint — roles are baked in at issue time, so an existing token will not pick them up |
| `403 not-owner` on update/delete | The test tried to modify data it did not create | Create your own data. This is the server's ownership check working |
| `404` immediately after a successful create | Read-after-write against a replica or cache | Poll with a deadline; do not sleep-and-hope |
| Timeout on an async pipeline | A worker stalled, or a downstream dependency timed out | Check the worker and gateway logs for the correlation id before raising the deadline |
| `429` / quota exhausted | Suite too hot, or two runs overlapping | Serialize, back off, or give the test identity its own quota |
| Passes alone, fails in the suite | Shared or leftover state between tests | Unique per-run names; assert only on self-created objects |
| Orphans left behind | Cleanup registered too late, or aborted by its own error | Register at creation; make cleanup idempotent; run the sweeper |
| Fails only in CI | Missing egress, missing secret binding, or different base URL | Compare the CI environment's variables against the runbook's export block |
| Database tests skip on a fresh machine | An ephemeral dependency was treated as gated | Ephemeral dependencies fail, not skip (section 11); install the server binaries |
| Ephemeral server starts on Linux, fails on macOS | Unix socket path over the platform limit | Pass a short socket directory (section 11) |
| Clone fails with "source database is being accessed by other users" | A session is attached to the template | Never connect to the template; only clone from it (section 11) |

## 9. When not to write one

- The behaviour is provable in a unit test with a fake, or against an ephemeral dependency
  the test starts itself (section 11) — write that; it never touches anything shared.
- The thing under test is a pure data transformation, a validation rule, or a formatting
  concern.
- The only available target is production and the test must mutate state that real users
  can see. Get an ephemeral or dedicated environment first; if none exists, restrict the
  suite to read-only probes and say so explicitly.
- The test would assert on data owned by someone else. That is monitoring, not testing —
  put it in the alerting stack instead.

## 10. CI wiring

- **Not on every pull request against a shared environment.** Manual dispatch, a schedule,
  or a post-deploy job against the environment that was just deployed.
- **Prefer an ephemeral environment.** A per-branch or per-run environment removes the
  entire class of problems this skill mitigates; the gate and cleanup rules still apply,
  because the same suite will be pointed at a shared environment eventually.
- **Credentials are injected from SECRET_MANAGER by the pipeline**, never pasted into the
  CI platform as a second source of truth that silently drifts after a rotation.
- **The gate is set in the job that needs it and nowhere else** — never in a global `env:`
  block that every job inherits.
- **Fail the job on cleanup failure**, and run the sweeper as an always-executed final
  step so a killed job still tidies up.
- **Publish the correlation ids and the environment name** in the job output; a red
  scheduled run is useless if nobody can tell which environment it hit.
- If the `cicd-build-deploy` skill is installed, wire the suite as a stage there; otherwise
  follow the project's own pipeline conventions.

## 11. Ephemeral dependencies on the default path

A test that needs a real database does not have to wait for a deployed environment. A
dependency the **test binary starts itself**, uses alone and throws away is not a shared
environment: none of the four invariants is at risk, so none of the gate machinery
applies. Such tests run on the default path, next to the unit tests.

- **They are not gated and they do not skip.** If the ephemeral dependency cannot start —
  binary missing, port busy, socket path too long — the test **fails** with a message
  naming the dependency and how to install it. Skipping would silently drop whatever the
  test proves, and these tests usually carry a spec's acceptance scenarios, which is
  exactly the coverage nobody notices is gone.
- **One cluster per test binary, one database per test.** Start the server once in the
  suite's entry point, create a *template* database with the migrations applied, then
  clone it per test — a clone from a template is a file copy and takes milliseconds,
  whereas re-running migrations per test does not. Stop the cluster in the same entry
  point, on failure too.
- **Each test owns its database and drops it.** Never share a database across tests, and
  never connect to the template: a template cannot be cloned while a session is attached
  to it, so parallel tests that touch it block each other.
- **An override is allowed, a default is not.** One environment variable may point the
  suite at an existing local server — a developer's own instance, a CI service — but when
  it is unset the suite starts its own. It never assumes one is running.
- **Short socket directory.** A server listening on a Unix socket needs the socket's full
  path to fit the platform limit — 104 bytes on macOS, 108 on Linux, file name included.
  The per-user temporary directory macOS hands out is already around fifty characters,
  so pass a short directory explicitly. The failure reads as "could not bind" or a
  truncated path, and it is the usual reason a suite works on Linux and fails on a Mac.
- **Same data discipline, smaller blast radius.** Unique names, reverse-order teardown, no
  fixed sleeps, deterministic clocks — section 5 still applies; only the gate and the
  credentials do not.

Illustration — the shape of the entry point and the per-test clone (Go; any ecosystem's
suite-level setup and teardown hooks work the same way):

```go
// Illustration (Go). TestMain owns the cluster; each test clones the template.
func TestMain(m *testing.M) {
    pg, err := testpg.Start(testpg.Options{SocketDir: shortDir()}) // fails, never skips
    if err != nil {
        log.Fatalf("ephemeral postgres: %v — install the server binaries, see docs/testing.md", err)
    }
    code := m.Run()
    pg.Stop() // explicit: os.Exit does not run deferred calls
    os.Exit(code)
}

func newDB(t *testing.T) *pgxpool.Pool {
    name := "t_" + uniqueSuffix()
    ident := pgx.Identifier{name}.Sanitize()                        // identifiers cannot be bound
    mustExec(t, admin, "CREATE DATABASE "+ident+" TEMPLATE app_template")
    t.Cleanup(func() { mustExec(t, admin, "DROP DATABASE "+ident) }) // LIFO: the pool closes first
    return connect(t, name)
}
```

If the `postgres-patterns` skill is installed, follow it for what the template's
migrations must contain (owner column, row-security policy); otherwise follow the
project's own schema conventions.

## Definition of done

- [ ] The suite skips cleanly with no environment configured, naming the gate variable.
- [ ] The gate is set nowhere by default — not in the Makefile, shell profile, devcontainer
      or CI global environment.
- [ ] The default test command passes offline, with no credentials present.
- [ ] Credentials come from SECRET_MANAGER at run time; no value appears in any tracked
      file, log line or CI variable.
- [ ] The test identity holds least privilege, and the server enforces ownership
      independently.
- [ ] Every created object carries the marker and a per-run unique id.
- [ ] Cleanup is registered at creation, is idempotent, and reports what it could not
      remove.
- [ ] The suite passes twice in a row against the same environment, and leaves no object
      matching the marker.
- [ ] A sweeper exists, is gated, and prints before it deletes.
- [ ] Tests against an ephemeral, test-owned dependency run on the default path, fail rather
      than skip when it cannot start, and clone a migrated template per test.
- [ ] The exact run command, including the export block, is in the project's runbook.
- [ ] Be honest about maturity: if the suite has never actually been executed against the
      environment, say so rather than implying it is green.

## Project delta

The consuming repo supplies:

- **Gate and environment variable names** and their required values (`<GATE_VAR>`,
  `<ENV_VAR>`), plus which environments exist and which gate unlocks which.
- **The test identity**: its name in the identity provider, the grant it uses, the exact
  roles/scopes it holds, and who may grant more.
- **Credential configuration variable names** (token URL, client id, client secret) and
  the SECRET_MANAGER entry and key that hold the secret, with the concrete fetch command.
- **The separation mechanism** — build tag, marker, directory, or filter — and the exact
  commands: default test target, integration target, smoke target, token target, sweeper.
- **The marker literal** and the field it is written into, plus the sweeper's age
  threshold.
- **Base URLs per environment**, and the endpoint used to confirm which environment
  answered.
- **Locations**: the integration test directory, the shared auth helper package, and the
  runbook page that carries the export block.
- **Timeouts**: the per-test deadline and the suite-level timeout for the slowest
  legitimate flow.
- **Which services' logs to read** when an asynchronous flow times out.
- **Ephemeral dependencies**: which ones the test binary starts, the helper that starts
  them, the override variable, the template database name, and the socket directory used
  on macOS.
