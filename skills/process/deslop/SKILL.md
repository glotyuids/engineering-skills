---
name: deslop
description: Strip machine-written slop out of a change — comments that restate the code, defensive handlers that swallow errors, unused abstraction layers, invented configuration options, "enhanced"/"comprehensive" naming, redundant re-validation, tests that assert the implementation instead of the behaviour — and decide honestly whether repeated logic should be extracted, using a Reusability Gate that forbids speculative abstractions and a rule that SOLID beats DRY. Use when the user says "deslop", "clean up this branch", "remove the AI slop", "this reads like it was generated", "too many comments", "why is there a wrapper around this", "remove duplication", "DRY this up", "extract common code", "extract reusable functions", "find duplication", or before opening a pull request on agent-written code.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Deslop — delete the residue, extract only what earns it

**Core rule: deleting is cheap, extracting is not. Slop cleanup must shrink the diff.
Duplication removal may add an abstraction only when at least two real call sites are
rewired to it in the same change.**

This skill defines only two operations on an existing change: (1) removing low-value
artifacts of machine-written code, and (2) deciding whether repeated logic becomes a
shared abstraction. It does not hunt for bugs, review correctness or security, replace
the project's formatter/linter, tune performance, or make architectural decisions. If
those are wanted, say so and run the appropriate review — deslopping a change does not
mean it works.

**Maturity note:** the catalogue below is distilled from repeated review findings on
agent-written changes, not from incident postmortems. That is why this skill carries no
`[!]` markers. If one of these patterns causes a production incident in your project,
mark it there.

## 1. Choosing the scope

1. If the user names a commit range, a branch, or a file list, use exactly that.
2. On a feature branch, diff against the project's base branch (`main` unless the project
   says otherwise).
3. On the base branch itself, diff the last commit (`HEAD~1..HEAD`). If the user mentions
   several commits, expand the range (`HEAD~3..HEAD`).
4. State the resolved scope in one line before editing, so the user can correct it.

The diff sets the **entry points**, not the boundary — section 5 explains when to look
outside it. Never expand scope silently: touching a file nobody asked about is itself a
form of slop.

## 2. Action A — slop cleanup (the default)

Work top-down through the changed hunks. Every edit is a deletion or a simplification;
if an edit adds a symbol, it belongs to Action B and must pass the Reusability Gate.

### The slop catalogue

| Pattern | How it looks | Action |
|---|---|---|
| **Comment restating the code** | A line above `save(user)` saying "save the user"; a block comment repeating the function name; step numbering that narrates control flow already visible | Delete. Keep only comments that carry *why*, a constraint, or a reference |
| **Docstring boilerplate** | Parameter/return sections that repeat the signature word for word, "This function is responsible for…", a summary generated from the identifier | Delete or rewrite to the one non-obvious fact. An empty docstring beats a wrong one |
| **Defensive handler that swallows** | `try`/`catch`/`recover`/`rescue` (or the language's equivalent) that logs and continues, returns a zero value, or converts a failure into a default — on a path where failure is not expected and not recoverable | Delete the handler and let the failure propagate. If it is genuinely recoverable, handle it for real: act on it, and say in the message what was lost |
| **Unused abstraction layer** | A wrapper, adapter, `*Manager`, `*Service`, `*Helper` or facade with one implementation, one caller, and no logic beyond forwarding arguments | Inline it into the caller and delete the layer |
| **Invented configuration** | An option, flag, env var, constructor parameter or struct field that nothing sets; a "configurable" threshold with exactly one value in the codebase; a strategy enum with one arm | Delete the option and inline the single value. Configuration is added when a second value exists, not before |
| **"Enhanced"/"comprehensive" naming** | `EnhancedX`, `AdvancedX`, `ComprehensiveY`, `RobustZ`, `SmartCache`, `UnifiedHandler`, `XV2`, `XNew`, `XImpl`, `process()`, `handleData()`, `doWork()` | Rename to the outcome it produces. If the name exists only to distinguish it from the version it replaced, finish the replacement and delete the other one |
| **Redundant re-validation** | The same precondition checked at the handler, then the service, then the repository; a null/empty check on a value the type system or the caller already guarantees | Validate once, at the boundary where untrusted input enters. Inside the boundary, assert only where a call can originate outside it |
| **Test asserting the implementation** | Mocks asserted call-by-call in order; a test that mirrors the function body statement for statement; snapshots of internal structures; asserting a private helper was invoked | Rewrite around observable behaviour: given these inputs, this output/effect. If rewriting kills the test entirely, the test was measuring nothing — delete it and say so |
| **Type-system escape hatch** | Casts, assertions, widening to the language's catch-all type, suppression directives — used to silence the checker rather than express intent | Express it in the type. If the cast is genuinely safe, keep it with a comment stating the invariant that makes it safe |
| **Deep nesting** | Three or more conditional levels inside one function; the happy path indented furthest right | Flatten with guard clauses, early returns, or extract-function (the extraction is local and single-use — it does not need the Gate) |
| **Dead scaffolding** | Unreachable branches, stub implementations, commented-out code, `example_usage()`, demo/sample callers, TODO placeholders with no owner | Delete. Version control is the archive |
| **Log narration** | An info-level line per step reproducing the control flow ("starting X", "X done"), duplicated at the caller | Keep the lines that a real consumer reads: errors, boundary crossings, and the ones the project's runbooks or dashboards depend on. Delete the rest |
| **Speculative error branches** | Handling for states the caller cannot produce; a `default:` arm for an exhaustive enum that returns a fabricated value | Delete, or make the impossible case fail loudly instead of returning something plausible |
| **Style drift** | Naming, import grouping, error-message casing, or idiom inconsistent with the surrounding file | Match the file, not your preference. If the project ships language conventions in an installed skill, follow that; otherwise follow the file |

### What is *not* slop — do not delete these

Over-deletion is the failure mode of this skill. Leave alone:

- **Error handling on a real trust boundary** — I/O, network, deserialization, user input,
  anything crossing a process. A handler that reacts (retries, falls back deliberately,
  wraps with context, reports) is doing work.
- **Comments carrying *why*** — a non-obvious constraint, a workaround with a link, a
  performance reason, a spec citation, an ordering requirement, a warning about a trap.
- **The one validation at the boundary.** When collapsing redundant checks, keep the
  outermost one that faces untrusted input, not the innermost one you happened to read
  first.
- **Repetitive-looking tests that are table cases** — each row is a distinct input.
- **An abstraction with two or more real implementations today** — that is not an unused
  layer, it is the Gate already satisfied.
- **Duplication that was kept deliberately** — if a comment says the copies evolve
  independently, respect it (section 8).

Before deleting any error path, check whether a test covers it. If one does, the path is
claimed behaviour: either keep both or delete both, and say which you chose.

## 3. Action B — duplication removal and extraction

Activate when the user says "deduplicate", "remove duplication", "DRY", "extract common",
"extract reusable", or "find reusable functions". Do not do this by default: unrequested
extraction turns a review-sized diff into a refactor.

### Analysis method — algorithmic, not textual

Do **not** compare raw lines or text similarity. Analyze at the level of **purpose,
structure, and data flow**:

1. **Purpose fingerprint.** For each function/method/block, name *what outcome* it
   produces — "validates input and returns the normalized form", "fetches a resource by
   id with retry", "maps a row into the domain type". Two blocks with the same fingerprint
   are duplication candidates even when their code looks nothing alike.
2. **Structural pattern.** Identify the algorithm skeleton — sequence of steps, branch
   topology, loop structure, error-handling shape. Two blocks following the same skeleton
   with different leaf expressions are structural duplicates.
3. **Data-flow shape.** Map inputs → transformations → outputs. Blocks with isomorphic
   data-flow graphs that differ only in concrete types, field names, or constants are
   extraction candidates.

Identical text with different purposes is *not* duplication — two constants that happen to
share a value, two validators that will diverge on the next requirement. Coincidence is
not commonality.

## 4. Scope for Action B — changed files plus global research

The diff determines the entry points, not the boundary. For every structural pattern found
in changed files, research the broader codebase for siblings:

1. **Fan out from the diff.** For each pattern in changed code (type shape, method
   skeleton, repeated constant, interface), search globally for other files following the
   same pattern — by type name, method signature, base type, or interface implementation.
   If a code-exploration agent is available, delegate the sweep; otherwise grep.
2. **Include unchanged siblings.** If a changed file is one of N siblings — one config
   loader among seven, one request handler among five — put **all** siblings in the
   inventory, not just the one in the diff. Extracting from two of seven and leaving five
   behind creates a third pattern.
3. **Detect scattered constants.** When the diff introduces or touches a literal (magic
   number, string id, enum value, header name), search for the same literal elsewhere.
   These are candidates for a shared constant or catalog.
4. **Check for existing abstractions first.** Before proposing anything new, search for a
   base type, helper, or utility that already exists and could serve the changed code. The
   best extraction is the one you do not have to write.

## 5. The Reusability Gate — no speculative code

Before extracting **any** function, helper, base class, interface, type parameter or
utility, every item below must be true. If even one fails, do **not** extract.

1. **Two real call sites today, minimum.** There must be ≥2 actual existing call sites in
   the current codebase that will be rewired to the extracted abstraction in this same
   change. "Will probably be useful later" is not a call site. In force-extract mode
   (section 9) the minimum is still 2 — never 1.
2. **No invented call sites.** Do not add a new caller just to justify the extraction. Do
   not add example/demo/sample usage. Do not add tests whose sole purpose is to give the
   extraction a second user.
3. **Every parameter is used now.** Each parameter, generic argument, callback, option
   flag, or config field of the extracted function must be required by at least one current
   call site. No optional/nullable/default-valued parameters added "for flexibility" with
   zero current caller using them.
4. **Every branch is reached now.** Each conditional, switch arm, strategy hook, or
   overload of the extracted abstraction must be exercised by at least one current call
   site. Delete unreached branches.
5. **No premature interfaces.** Do not introduce an interface, abstract class, or virtual
   hook unless there are ≥2 concrete implementations today **and** at least one consumer
   that depends on the abstraction rather than the concrete type. One implementation behind
   an interface is speculative.
6. **No new "utils"/"common"/"helpers" bucket.** Place extracted code next to its primary
   user or inside an existing cohesive unit (package, module, namespace — whatever the
   project uses). A new shared unit requires ≥3 unrelated consumers and a real domain name
   — never `utils`.
7. **Narrowest signature.** Prefer concrete types over generics, value parameters over
   callbacks, and direct calls over registries — unless the stricter form genuinely cannot
   serve every current call site.

If a candidate fails the Gate but the duplication is still painful, prefer, in order:
inline the second copy back into its caller, delete the unused copy, or leave a
`TODO(deslop): revisit if a third caller appears` comment beside the duplicates. Leaving a
marker is a legitimate outcome — it is cheaper to reverse than a wrong abstraction.

## 6. Extraction procedure

1. **Inventory.** List every candidate pair/group with a one-line purpose description and
   the files and line ranges involved, including unchanged files found during research.
2. **Apply the Gate.** Check all seven rules per candidate. Mark each `extract`,
   `keep-duplicated`, or `delete-unused`. Reject any candidate that would need an invented
   caller to pass.
3. **Rank.** Order surviving `extract` candidates by impact — most duplicated, or most
   likely to diverge incorrectly, first.
4. **Design the narrowest mechanism** that still serves every current call site:

   | Situation today | Mechanism |
   |---|---|
   | Skeleton identical, variation in 1–3 leaf values | Extract function; pass the values as parameters |
   | One step varies in *logic*, and ≥2 current callers need different logic there | Extract function with a strategy callback for that step only |
   | Skeleton identical, operating on ≥2 different concrete types today | Generic/parameterized type |
   | ≥2 concrete implementations today, the abstraction is a real domain concept, and ≥1 consumer depends on the abstraction rather than the concrete type | Interface plus implementations |

5. **Apply.** Move the shared logic into the new abstraction and update **all** call sites
   — including the unchanged siblings found in research — in the same change. An extraction
   with unmigrated call sites is half-done and counts as new speculative code.
6. **Verify.** Confirm no behaviour change: the same inputs produce the same outputs and
   effects at every call site. Confirm every parameter and every branch of the new
   abstraction is exercised by a real caller. Run the project's tests; if none cover the
   touched paths, say so rather than implying the extraction is proven.

## 7. Naming the extraction

The extracted symbol is named for the outcome, in the vocabulary of the domain it serves —
not for the fact that it is shared. `normalizeEmail`, not `emailUtil`; `retryWithBackoff`,
not `commonHelper`; `ParseCursor`, not `SharedParser`. If no honest domain name exists, the
two call sites probably do not share a concept — recheck rule 1 and the purpose
fingerprints.

## 8. SOLID overrides DRY

If extracting a shared abstraction would violate Single Responsibility, or couple two
domains that must evolve independently, **keep the duplication**. Add one short comment at
each copy explaining why, for example:

```
// intentional duplication — the billing and reporting projections evolve independently
```

Then **say it out loud** in the summary: name the candidate, say you chose duplication, and
say why. A deliberate choice that is not reported reads as a miss on the next review, and
the next agent will "fix" it.

Precedence, in order: the Reusability Gate wins over DRY; SOLID wins over DRY; DRY never
overrides either. Coupling is more expensive than typing.

## 9. Guardrails

- Keep behaviour unchanged unless fixing a clear bug — and if you fix one, report it
  separately from the cleanup.
- Prefer minimal, focused edits over broad rewrites. A deslop diff that is larger than the
  diff it cleans has failed.
- Slop cleanup must not introduce new abstractions beyond what removing the slop requires.
- Duplication removal **may** introduce abstractions, but only the narrowest viable one —
  never speculative generalization, never code "for future reuse".
- Every extracted symbol must have ≥2 real, current call sites wired up in the same change.
  No invented callers, no demo usages, no future-proof parameters or hooks.
- Do not reformat or re-lint untouched lines; that noise hides the real edits.
- When the user says "force extract", extract borderline candidates that would normally be
  left as-is — but the SOLID override and the whole Reusability Gate still apply, and the
  two-call-site minimum is never waived.
- Do not delete a test to make a change pass. Rewriting a test around behaviour is in
  scope; deleting coverage is a separate decision the user makes.
- If the project ships a commit or branch convention in an installed skill, follow it when
  committing; otherwise leave the change uncommitted and let the user decide.

## 10. Output

Give a concise summary — one to three sentences per action — of what was cleaned and why.

For slop cleanup, group by pattern from the catalogue with a count and the files touched
("7 restating comments, 2 swallowing handlers, 1 unused wrapper layer").

For duplication removal, list each extraction with:

- before locations (files and line ranges of the duplicated code) and after location (the
  new shared symbol),
- the count of current call sites now wired to it (must be ≥2),
- every candidate rejected by the Gate, with a one-line reason ("only 1 real caller",
  "would need invented usage", "would create a premature interface", "new utils bucket"),
- every candidate deliberately left duplicated under the SOLID override, with the reason.

State plainly what you did not verify — untested paths, siblings you found but did not
migrate, patterns you spotted outside the agreed scope.

### Definition of done

- [ ] Scope was stated and not silently widened.
- [ ] Every remaining comment says *why*, not *what*.
- [ ] No handler swallows a failure it does not act on.
- [ ] No option, parameter, branch or interface exists without a current user.
- [ ] Names describe outcomes; no "enhanced"/"advanced"/"V2" survivors.
- [ ] Each precondition is validated once, at the boundary.
- [ ] Tests assert observable behaviour, and coverage did not shrink silently.
- [ ] Every extracted symbol has ≥2 real call sites wired up in this change.
- [ ] All siblings of an extracted pattern were migrated, or the omission is reported.
- [ ] Behaviour is unchanged; the project's tests were run, or their absence was stated.
- [ ] Rejected candidates and deliberate duplication are both named in the summary.

## Project delta

The consuming repo supplies:

- The base branch name for the default diff, and whether unrelated cleanups may ride along
  in a feature branch.
- Where extracted code lives — the existing cohesive packages/modules, and any the project
  forbids growing.
- The test command to run for verification, and what "coverage did not shrink" is measured
  against, if anything.
- Language and style conventions the cleanup must match (formatter, linter, naming), and
  the comment syntax for the `TODO(deslop)` marker.
- Any directory exempt from deslopping — generated code, vendored dependencies, fixtures.
