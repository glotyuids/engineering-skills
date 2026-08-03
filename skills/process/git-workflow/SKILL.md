---
name: git-workflow
description: Branching, commit hygiene, submodules, merge strategy and the git-state checks a deploy depends on. Use when committing, writing a commit message, staging changes, creating or naming a branch, pushing, merging or squash-merging a feature branch into the trunk, rebasing, resolving a push rejection or merge conflict, working in a repo that has git submodules, or checking whether the working tree is clean before a build or deploy. Triggers on "commit this", "write the commit message", "push it", "merge to main", "squash-merge", "the push was rejected", "the submodule is dirty", "detached HEAD", "should I force-push?", "can I amend that?", "why is the image tagged dirty", "clean up the branch before deploy".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Git workflow

This skill defines only how **git state is moved**: what a commit contains and how its message
reads, how branches are named and merged, how submodules are advanced without breaking the
parent, and the git-state gates a deploy depends on. It does not define review process, release
versioning, changelog format or CI configuration. It assumes no language and no cloud provider:
every rule here holds for any repository.

If the `documentation-standards` skill is installed, follow it for what a change must document;
this skill only says the documentation lands in the same commit as the change.

## 1. Commit hygiene

### Message format

Conventional commits: `type(scope): description`

| Part | Rule |
|---|---|
| `type` | one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci` |
| `scope` | service or component name, or `infra`; omit for cross-cutting changes |
| description | imperative mood, lower case, no trailing period — `add token refresh`, not `Added token refresh.` |
| body | optional, wrapped at 72 chars, separated by a blank line |

**The subject says what changed; the body says why.** The diff already shows what. A body that
restates the diff is noise; a body that records the constraint, the alternative rejected, or the
bug the change fixes is the only place that information will ever exist. If a reviewer would ask
"why like this?", answer it in the body before they ask.

Use a heredoc for multi-line messages so quoting and newlines survive intact:

```bash
git commit -m "$(cat <<'EOF'
feat(auth): add token refresh endpoint

Sliding-window expiry rather than fixed TTL: clients poll on an
interval we do not control, and fixed TTL logged them out mid-session.
Updates the API spec in the same commit.
EOF
)"
```

### What goes in a commit

- **One logical change per commit.** Do not bundle an unrelated rename, formatting sweep or
  dependency bump with a behaviour change — it makes the behaviour change unreviewable and
  unrevertable.
- **Stage explicit paths** (`git add <path>`), not a blind `git add .` / `git add -A`. Blind
  staging is how a scratch file, a local config override, an editor directory or a credential
  file enters history.
- **Never commit generated files that the build produces.** Compiled artifacts, bundles,
  generated clients, coverage output, dependency directories, lockfile-adjacent caches: if
  `make build` (or the project's equivalent) recreates it, it belongs in `.gitignore`, not in
  the tree. Committed build output desynchronises from source silently and produces conflicts
  nobody can resolve meaningfully. Committed *inputs* — lockfiles, checked-in schemas, generated
  code the build does **not** regenerate — are a deliberate, documented exception.
- **Never commit secrets** — values, tokens, key files, `.env` with real content. If the
  `secrets-management` skill is installed, follow it for where values belong; otherwise follow
  the project's own convention. A secret that reached a remote is leaked even after the history
  is rewritten: **rotate the value**, then clean up. Rewriting history is not a remediation.
- **Do not bypass hooks** (`--no-verify`, skipping pre-commit checks) to get a commit through. If
  the hook is wrong, fix the hook in its own commit.
- Documentation, migration and test changes belong in the same commit as the code they describe.

## 2. Branch and merge strategy

Trunk-based development: one long-lived trunk (`main` in the examples below — the project names
its own) plus **short-lived** feature branches.

- Branch from an up-to-date trunk: `git checkout main && git pull && git checkout -b feat/<topic>`.
- Name branches `<type>/<short-topic>` using the same type vocabulary as commits.
- Keep them short-lived. A branch alive for weeks stops being a feature branch and becomes a
  fork; rebase onto the trunk frequently instead.
- Push after each user-requested block of work, so remote history is not a single end-of-day dump.

### Merging to the trunk

1. **Push the feature branch to its remote first.** This preserves the detailed step-by-step
   history remotely even though the trunk will only get one commit.
2. Squash-merge: `git checkout main && git merge --squash <branch>`.
3. **Write a real message summarising all the changes.** `merge feat/xyz` is not a message — the
   squash commit is now the only description of the work on the trunk, so it carries the *why*
   for the whole branch.
4. Push the trunk immediately after the squash commit. A local-only trunk commit is invisible to
   everyone and blocks the next person's merge.

### History rules

- **Never force-push the trunk.**
- **Never rewrite published history.** Once a commit is on a shared branch, or on any branch
  someone else may have fetched or based work on, it is immutable: no `rebase`, no `commit
  --amend`, no `reset --hard` followed by a force push. Fix forward with a new commit or a
  `revert`.
- Force-push **is** acceptable on a personal feature branch nobody else has based work on —
  that is what rebasing before a merge requires. Prefer `--force-with-lease` so a colleague's
  unexpected push is not silently discarded.
- Protected-branch rejections are a signal, not an obstacle (see §6).

## 3. Submodule protocol

These rules apply to any repository that uses git submodules. Submodules fail quietly: the
parent records a pointer to a commit, and nothing verifies that the commit is reachable by
anyone else.

### 3.1 Preflight — before any parent commit, push or merge

Run `git submodule status` in the parent repository. For each submodule, check:

1. **Dirty working tree** (`+` prefix, or modified content inside) — commit and push *inside the
   submodule first*.
2. **Detached HEAD** (`(HEAD detached at …)`, or a status line with no branch) — check out the
   correct branch inside the submodule before committing anything. A commit made on a detached
   HEAD is unreachable the moment you check out anything else.
3. **Wrong branch** — if the parent is being merged to the trunk, the submodule must also be on
   its trunk, or have been merged to its trunk first. A trunk parent must never point at a
   feature-branch commit.

### 3.2 Execution order

When both the parent and a submodule have changes, the order is fixed — inner repository first,
always:

```text
submodule: commit → push → (if merging to trunk: merge to trunk → push trunk)
parent:    git add <submodule-path> → commit → push
```

`[!]` **Never leave a submodule pointer referencing a commit that has not been pushed to the
submodule's remote.** The parent commit looks perfectly healthy on the machine that made it and
is broken for everyone else and for every clean checkout: `git submodule update` fails with a
"reference is not a tree" style error, and the build host cannot resolve the pointer. This is
the single most common way a repository is broken for the whole team by one push.

After pulling a parent that advanced a pointer, sync the working copy:
`git submodule update --init --recursive`. Clone with `--recurse-submodules`.

### 3.3 Decision matrix

| Parent action | Submodule dirty? | Submodule on a feature branch? | Required steps |
|---|---|---|---|
| Commit on feature branch | Yes | Yes | Commit + push submodule, then parent |
| Commit on feature branch | No | Yes | Just the parent commit |
| Squash-merge to trunk | Yes | Yes | Commit + push submodule, squash-merge submodule to its trunk, push trunk, then parent |
| Squash-merge to trunk | No | Yes | Squash-merge submodule to its trunk, push trunk, then parent |
| Squash-merge to trunk | No | No (already on trunk) | Just the parent |

Reading the matrix: the parent is *always last*, and "dirty" only ever adds work inside the
submodule. There is no row in which the parent moves first.

## 4. Pre-deploy check

`[!]` **Build artifacts are tagged from git state, so an unclean tree produces an
unidentifiable build.** Tooling that derives a version from `git describe` / the commit SHA
appends a dirty marker (or invents a tag) when the tree has uncommitted changes; the resulting
artifact cannot be traced back to any commit, cannot be reproduced, and cannot be reasoned about
during an incident — "which code is running?" has no answer.

Before running any deploy or release target:

1. `git status` — the working tree must be clean, with no uncommitted or untracked changes.
2. `git submodule status` — no dirty submodules, if the repository has any.
3. If either is dirty, **stop and tell the user** what is uncommitted and that the build will be
   tagged as dirty. Do not "just deploy anyway".
4. Commit and push first, then deploy.
5. Deploy from a branch whose commits are on the remote — a local-only commit is not
   reproducible by anyone else, including a rollback later.

If the `cicd-build-deploy` skill is installed, its tagging and deploy-safety rules apply on top
of this check; otherwise follow the project's own build conventions. Either way, this git-state
gate runs first.

## 5. Postflight verification

After any push:

1. `git status` — confirm the branch is up to date with its remote tracking branch (not "ahead
   by N"). A push that printed no error but left commits behind is common after a hook or a
   partial failure.
2. If submodules were involved, `git submodule status` shows a clean state — no `+` prefix, and
   the recorded SHAs are the ones that were pushed.
3. If the change is going to be deployed, re-run the §4 check on the deploy machine's checkout,
   not only on the machine that authored the commit.

## 6. Failure handling

| Failure | Recovery |
|---|---|
| Submodule push rejected | Pull/rebase inside the submodule, resolve conflicts, push again. **Do not proceed with the parent commit** until the submodule push has landed. |
| Parent push rejected (non-fast-forward) | `git pull --rebase`, resolve conflicts, push again. Never resolve by force-pushing a shared branch. |
| Merge conflict during a squash-merge | Resolve, complete the merge, then push. If the conflict is large or semantic rather than textual, stop and ask the user. |
| Protected-branch rejection | Stop and report to the user. Do not attempt workarounds — no direct push with a different credential, no branch-protection change, no "temporary" bypass. |
| Detached HEAD with work already committed | Note the SHA before checking out anything, then create a branch at it (`git branch <name> <sha>`) — otherwise the commit is unreachable. |
| Committed a secret | Rotate the value **first**. Treat the history rewrite as cleanup, not as the fix. |
| Committed to the wrong branch | If unpushed: create the correct branch at HEAD, reset the wrong one. If pushed to a shared branch: revert forward, do not rewrite. |
| A submodule pointer references a missing commit | Push the missing commit from whoever has it; if it is genuinely lost, move the pointer to a commit that exists and re-do the work. |

**When in doubt, stop and ask the user before proceeding.** Every irreversible git operation —
force-push, hard reset, history rewrite, branch deletion — needs explicit intent for that
specific action, not a general "yes, commit and push".

## 7. Definition of done

- [ ] Each commit is one logical change, staged from explicit paths.
- [ ] The subject follows `type(scope): description`; the body explains *why* where it is not obvious.
- [ ] No generated build output, no secrets, no local-only config in the diff.
- [ ] Docs, tests and migrations belonging to the change are in the same commit.
- [ ] All submodules are committed and pushed **before** the parent references them.
- [ ] `git status` is clean and the branch is not ahead of its remote.
- [ ] Nothing published was rewritten; the trunk was never force-pushed.
- [ ] For a merge: the branch was pushed first, the squash commit describes the whole branch,
      and the trunk was pushed immediately after.
- [ ] For a deploy: §4 ran and passed on the checkout the build will use.

## Project delta

The consuming repo supplies:

- The trunk branch name, and whether it is protected.
- The commit `scope` vocabulary — the service/component names that are legal scopes.
- Whether the repo uses submodules, their paths, and the branch each submodule tracks.
- Any merge policy imposed by the host (pull requests required, review count, status checks) —
  this skill assumes the squash-merge shape but does not require a specific host.
- The deploy/release targets that §4 gates, and how their versions are derived from git state.
- The ignore rules for generated output, if the defaults do not cover the toolchain in use.
