# Runbook: <verb the thing>

**When to run this:** the trigger, in one line.
**Blast radius:** what this touches, and what it cannot touch.
**Time:** rough duration.

## Safety model — read before cutting over

What can go wrong, what is reversible, and what is not. If any step is irreversible, say
so here, not in the middle of the procedure.

## Preconditions

- [ ] Access required (which context, which role)
- [ ] State that must already be true
- [ ] Clean working tree if the deploy tags artefacts from git state

## Procedure

1. Step, with the exact command and the expected output.
2. …

## Verification

How you know it worked — the specific check, not "confirm it works".

## Rollback

The exact steps to get back. If rollback is impossible past a certain step, mark that
step as the point of no return.

## Known failure modes

| Symptom | Cause | Fix |
|---|---|---|
