---
name: kanban-md
description: Run a project board that lives in the repository as markdown files — one task per file with YAML frontmatter — so agents and humans share one task list. Use when the user mentions the board, kanban, backlog, sprint, task, ticket, work item, priority, blocker, WIP limit, standup, triage or project metrics, or asks to create, list, show, claim, pick, start, update, block, hand off, complete, archive or delete a task. Triggers on "what should I work on next", "what's on the board", "show the backlog", "add a task for this", "file a bug on the board", "move it to in-progress", "mark it done", "is anything blocked", "park this and hand it off", "update the task with what we found", "plan the sprint", "run standup".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Kanban in markdown

This skill defines only how a **file-based board** is operated: where the task files live, what
a task file contains, how a task moves through its states, and the rules an agent follows when it
touches the board. It does not define what work is worth doing, how the work is estimated, or how
the code is written. It assumes no language and no cloud provider.

## 1. The pattern

The board is a directory in the repository. One task is one markdown file with YAML frontmatter;
the frontmatter is the structured state, the body is the human-readable content. Because the board
is in the repo, a task and the diff that resolves it live in the same history, review the same way,
and branch the same way.

```text
kanban/
  tasks/
    <ID>-<slug>.md      # one file per task
  ...                   # board configuration: status + priority vocabulary, WIP limits
```

**The board CLI.** These conventions are usually driven by a small CLI, conventionally invoked as
`kanban-md` (this skill is named after it). Every command in this skill is written as
`kanban-md <command>`; substitute your project's binary name or path. If the project pins the
binary somewhere in-tree, or the board is not at the repository root, wrap it once:

```bash
kanban-md --dir kanban <command>     # --dir points at the board directory
```

**Without the CLI.** A project that has no such binary applies the *same file conventions by hand*:
create the file, fill the frontmatter, edit the body, change `status:` when the work moves. The
field names, states and lifecycle in this skill are the contract; the CLI is a convenience that
keeps the frontmatter well-formed and the timestamps honest.

`Verify:` flag names below follow one widely used implementation. Confirm with `kanban-md --help`
(and `kanban-md board`) before scripting against them — statuses, priorities and flags are
board-specific.

## 2. Task file shape

### Frontmatter

| Field | Meaning |
|---|---|
| `id` | Stable task identifier. Referenced from branches, commits and other tasks. Never reassigned. |
| `title` | One line, imperative, specific enough to be recognisable in a list. |
| `status` | Current column. Board-specific vocabulary — see §3. |
| `priority` | Board-specific ranking. Read the board before assuming a scale or its direction. |
| `assignee` | Human owner, if the board tracks people. |
| `tags` | Free-form labels used for filtering (`bug`, `docs`, a component name). |
| `created` / `updated` | Maintained by the CLI. Do not hand-set. |
| `started` / `completed` | Set automatically on the first move out of the initial status and on the move to a terminal status. |
| `due` | `YYYY-MM-DD`. Drives the overdue view. |
| `estimate` | Size, in whatever unit the board declares. |
| `parent` | Umbrella/epic task this one belongs to. |
| `depends_on` | Task IDs that must reach a terminal status first. Drives blocked/unblocked queries. |
| `blocked` + reason | Explicit block, independent of dependencies. Always carries a reason. |
| `claim` | Which agent currently owns execution, and when the claim was taken. See §4. |
| source fields | On imported tasks: the original ID, source URL and source notes. |

### Body

Keep the body concrete and current. A structure that works:

```markdown
## Outcome        # what is true when this is done
## Why            # the reason it is worth doing
## Acceptance     # checkable conditions, not aspirations
## Repo paths     # where the change lands
## Depends on     # prose form of the dependency, with IDs
## Next action    # the single next step, so a resumed task is not re-derived
```

Append progress, decisions and validation evidence to the body as the work proceeds; do not rewrite
history in it. Truthfulness matters more than tidiness: a body that claims tests pass when they were
never run is worse than an empty body.

## 3. States and lifecycle

Statuses are board-specific. A common default set is `backlog → todo → in-progress → review → done`,
with terminal statuses (`done`, and often `rejected`/`archived`) ending the flow. **Read the actual
vocabulary from `kanban-md board` before using any value** — hardcoded statuses are the most common
way an agent corrupts a board it has never seen.

| Phase | Trigger | Board action |
|---|---|---|
| 1. Enter | Work is identified and worth remembering | `create` in the intake status (`backlog`/`ideas`) |
| 2. Promote | Work is agreed and ready to start | `move` to `todo` |
| 3. Start | Implementation actually begins | `claim` + `move` to `in-progress` |
| 4. Progress | A meaningful step lands | Append a timestamped note; renew the claim |
| 5. Park | Waiting on a decision, a review or an external event | `handoff` to `review` with a note; block with a reason if the wait is external |
| 6. Finish | Acceptance conditions hold **and** the evidence exists | Release the claim, `move` to the terminal status |

Move to `in-progress` **only when implementation starts** — not when the task is read, planned or
sized. An `in-progress` column that reflects intent instead of activity makes WIP limits meaningless.

## 4. Claims (multi-agent boards)

A claim is a soft lock recording that one agent is executing a task, so parallel agents do not
collide on the same work.

```bash
kanban-md agent-name    # once per session: generates a stable two-word identity; remember it
```

- Take a claim when starting, renew it with each progress note, release it when finishing or parking.
- Prefer the atomic `pick` (§5) over `list` → `edit --claim` → `move`: the three-step sequence has a
  race window in which two agents claim the same task.
- **Resume before picking.** If an executable task is already `in-progress` under your identity,
  continue it rather than claiming another. Half-finished work with no owner is how a board grows
  a permanently stalled column.
- An umbrella task (`parent` of others) is never claimed. Execute its children; close it when they
  are all closed.

## 5. Command surface

| Intent | Command |
|---|---|
| Board overview / standup | `kanban-md board --compact` |
| Get a session identity | `kanban-md agent-name` |
| List tasks | `kanban-md list --compact` |
| Filter by status / priority | `kanban-md list --compact --status todo,in-progress --priority high,critical` |
| Filter by assignee / tag | `kanban-md list --compact --assignee <name> --tag bug` |
| Blocked / ready-to-start | `kanban-md list --compact --blocked` / `--not-blocked --status todo` |
| Dependencies all resolved | `kanban-md list --compact --unblocked` |
| Read one task in full | `kanban-md show <ID>` |
| Claim the next task atomically | `kanban-md pick --claim <agent> --status todo --move in-progress` |
| Create | `kanban-md create "TITLE" --priority <P> --tags <T> --body "TEXT"` |
| Create and claim in one step | `kanban-md create "TITLE" --priority <P> --claim <agent>` |
| Move | `kanban-md move <ID> in-progress` (or `--next` / `--prev`) |
| Edit fields | `kanban-md edit <ID> --title "NEW" --priority <P>` |
| Tags / due date | `kanban-md edit <ID> --add-tag <T> --remove-tag <T> --due YYYY-MM-DD` |
| Block / unblock | `kanban-md edit <ID> --block "REASON"` / `--unblock` |
| Dependencies / hierarchy | `kanban-md edit <ID> --add-dep <DEP_ID> --parent <PARENT_ID>` |
| Append a progress note | `kanban-md edit <ID> -a "note" -t --claim <agent>` |
| Park for someone else | `kanban-md handoff <ID> --claim <agent> --note "…" -t --release` |
| Delete | `kanban-md delete <ID> --yes` |
| Flow metrics | `kanban-md metrics --compact` |
| Activity log | `kanban-md log --compact --limit 20` (add `--task <ID>`) |
| Board summary for an agent file | `kanban-md context --write-to <FILE>` |
| Initialise a board | `kanban-md init --name "NAME"` |

Notes on the commands that are easy to misuse:

- **`list`** sorts on `id, title, status, priority, created, updated, due`; `-r` reverses, `-n` limits.
- **`create`** prints the new ID — capture it, everything else needs it.
- **`edit`** changes only the fields passed, accepts comma-separated IDs for bulk edits, and
  `-a`/`--append-body` appends rather than replacing (`-t` prefixes a timestamp).
- **`move`** sets `started`/`completed` automatically; `--next`/`--prev` fail at the boundary
  statuses, and cannot be combined with an explicit status.
- **`pick`** takes the highest-priority unclaimed, unblocked task in one atomic step.
- **`handoff`** moves to `review`, appends the note, and optionally blocks and/or releases.
- Global flags: `--json`, `--table`, `--compact` (alias `--oneline`), `--dir <PATH>`, `--no-color`.

## 6. Operating rules

These are the rules that decide whether the board stays trustworthy. They apply whether the changes
go through the CLI or are made by hand.

1. **Drive normal changes through the CLI, not the frontmatter.** `create`, `edit`, `move`,
   `handoff`, `archive` keep IDs, timestamps, claims and derived state consistent. Hand-editing the
   YAML is a **repair tool** — for a file the CLI can no longer parse — not the everyday interface.
   After a hand repair, run `kanban-md show <ID>` to confirm the file reads back correctly.
2. **Never dual-write to a second task system.** One board is the operational source of truth. Do
   not mirror tasks into an external tracker, an issue list, a spreadsheet or a `TODO.md` "so both
   stay current" — two systems diverge within days, and every later reader has to guess which one
   lied. If an external tracker is the origin, import once and preserve the source ID, source URL
   and source notes on the task; treat the import as history, not as a live link to keep in sync.
3. **Do not update the board merely because a file changed.** The board is updated when the work
   came from a board task, or when the user asked for task work. Incidental edits, exploratory
   reads, answering a question and drive-by fixes do not create or move tasks. A board that
   auto-narrates every diff becomes noise nobody reads.
4. **One task per unit of reviewable work.** If a task cannot be finished, reviewed and merged as
   one coherent change, split it — with `parent` for hierarchy or `depends_on` for ordering. A
   discovered follow-up that could be prioritised independently becomes its **own** task; it does
   not silently expand the current one.
5. **A task is not done until its evidence exists.** The acceptance conditions must be checkable and
   checked: tests written and run, documentation updated, the command output or verification step
   recorded in the body. "Implemented" is not "done". If the evidence cannot be produced, park the
   task in `review` with a note saying exactly what is missing.
6. **Keep durable documents in sync in the same change.** When a task alters an architectural or
   product decision, update the decision record the project keeps and reference its path from the
   task body, with the evidence. If the `documentation-standards` skill is installed, follow it for
   what belongs where; otherwise follow the project's own convention.
7. **Preserve imported identifiers.** Imported task IDs, source URLs and source notes are changed
   only when the task itself is deliberately being re-scoped.
8. **Read the project's own work-management document first**, if it has one. It overrides the
   defaults in this skill: status vocabulary, priority direction, WIP limits, claim policy.
9. **Commit board changes with the work they describe.** A git-tracked board is reviewed like code.
   If the `git-workflow` skill is installed, its commit rules apply; otherwise keep the board change
   and its code change in one commit, or in an adjacent board-only commit when the work spans several.
10. **Verify after mutating.** Run `kanban-md board` and review the git diff of the board directory.
    Board writes are file writes: a wrong `--dir`, a mistyped ID or a bulk edit with one bad ID in
    the list is visible in the diff and nowhere else.

## 7. Routine workflows

**Standup / status.** `board --compact` → `list --compact --status in-progress` →
`list --compact --blocked` → `metrics --compact`. Report completed, active, blocked, aging.

**Triage.** `list --compact --status backlog --sort priority -r` → promote with `move <ID> todo`,
add missing items with `create`, delete genuinely dead items with `delete <ID> --yes`.

**Planning.** `board --compact` for capacity → `list --compact --status backlog,todo --sort priority -r`
for candidates → promote, `edit <ID> --assignee <name>`, `edit <ID> --due YYYY-MM-DD`.

**Agent session.**

```bash
kanban-md agent-name                                              # identity, once
kanban-md board --compact                                         # orient
kanban-md pick --claim <agent> --status todo --move in-progress   # claim atomically
kanban-md show <ID>                                               # read it fully

kanban-md edit <ID> -a "Implemented X; tests green." -t --claim <agent>   # progress + renew

kanban-md edit <ID> --release                                     # finish
kanban-md move <ID> done
```

**Park or hand off.**

```bash
kanban-md handoff <ID> --claim <agent> \
  --note "Ready to merge on branch task/<ID>; waiting on: <what>." -t --release

kanban-md handoff <ID> --claim <agent> --block "<what is blocking>" \
  --note "To unblock: <step>. Next action after that: <step>." -t --release
```

**Resume a parked task.** `edit <ID> --claim <agent>` → `edit <ID> --unblock --claim <agent>` if it
was blocked → `move <ID> in-progress --claim <agent>`.

**Dependency chain.** `create "Epic"` → `create "Subtask" --parent <PARENT_ID>` →
`create "Task B" --depends-on <TASK_A_ID>` → check with `list --compact --blocked`.

## 8. Pitfalls

`[!]` **Never pass unescaped text through a double-quoted body argument.** Backticks and `$(…)`
inside double quotes are shell command substitution, so a task body containing them is *executed*
instead of stored — with the agent's full privileges, silently, before the CLI ever sees the string.
Escape every backtick (`` \` ``), quote the outer string with single quotes, or pass the body from a
file. This applies to `--body`, `--append-body`, `--note` and `--block`.

| Do | Do not |
|---|---|
| Use `--compact` for `list`, `board`, `metrics`, `log` — cheapest readable output | Use `--json` for reading; it is for piping into another tool |
| Read task detail with `show <ID>` (default format includes the body) | Assume `show` output is stable enough to parse without `--json` |
| Pass `--yes` to `delete` | Omit it — the command blocks on stdin in a non-interactive session |
| Read statuses and priorities from `board` | Hardcode `todo`/`high` and hope the board agrees |
| Check the current status before `--next` / `--prev` | Combine `--next`/`--prev` with an explicit status |
| Quote titles containing punctuation | Leave `Fix: the 'login' bug` unquoted |
| Use the non-interactive commands | Launch the interactive TUI when no interactive terminal exists |
| Renew the claim with each progress note (`-a … --claim`) | Overwrite a body with `--body` when you meant to append |

## 9. Definition of done

- [ ] The task exists on the board before the work is claimed as board work.
- [ ] Its status reflects reality: `in-progress` only while implementation is actually happening.
- [ ] The body carries outcome, acceptance, next action, and the evidence produced so far.
- [ ] The claim was released, or the task was handed off with a note saying what is awaited.
- [ ] Acceptance conditions were checked, not asserted — tests run, docs updated, output recorded.
- [ ] Durable documents touched by the change were updated and referenced from the task body.
- [ ] Follow-ups that can be prioritised independently were filed as their own tasks.
- [ ] No task state was mirrored into a second tracker.
- [ ] The board diff was reviewed and committed with (or beside) the work it describes.

## Project delta

The consuming repo supplies:

- The board directory, and whether it is git-tracked (it should be) and committed with the work.
- The status vocabulary and which statuses are terminal.
- The priority scheme **and its direction** — which end is most urgent — plus any meaning attached
  to priority bands, such as a mapping to milestones.
- WIP limits, and which statuses require a claim.
- The task body template, if it differs from the one in §2.
- Which durable documents (decision log, architecture records, changelog) a task must keep in sync,
  and where they live.
- Where the board CLI is installed and how it is invoked, or the statement that the project has none
  and the conventions are applied by hand.
- Any project work-management document that overrides the rules in §6.
