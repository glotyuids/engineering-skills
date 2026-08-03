---
name: skill-authoring
description: Author, review and measure agent skills — spec-conformant SKILL.md frontmatter, a description engineered so the agent loads the skill at the right moment, a body sized for progressive disclosure, portable phrasing that survives a partial install, and assertion-based evals run with-skill versus without-skill. Use when creating a new skill, splitting an oversized SKILL.md into references, reviewing or fixing someone else's skill, or when the user says "write a skill", "author a SKILL.md", "the skill never triggers", "it loads when it shouldn't", "fix the description", "make this skill portable", "add evals for this skill", "benchmark the skill", or "does the skill actually help". Also use whenever a SKILL.md, an evals/evals.json or a skills/ directory is being read or edited in the session, even if the word "skill" is never said. For designing the tool server a skill drives, use mcp-server-authoring instead.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Skill authoring — triggers, portability, evals

**Core rule: the description is the product. It is the only part of a skill that is in
context when the agent decides whether to load it, so a perfect body behind a vague
description is dead weight.**

A skill is a directory holding `SKILL.md` — YAML frontmatter plus Markdown instructions —
conforming to the [Agent Skills specification](https://agentskills.io/specification).
Anything an agent can be told, a skill can carry; what makes it *work* is that it is found
at the right moment, survives being installed into a project you have never seen, and can
be shown to change behaviour.

This skill defines only: the file format and its field rules; how to write a description
that triggers; how to shape and size the body; the portability rules that keep a skill
usable outside the repo it was written in; and the eval methodology that proves it helps.
It does not define what any particular domain skill should say, prompt engineering for
model APIs, or how a specific agent product installs skills (its own docs own that).

## 1. The file and its frontmatter

| Field | Required | Rule |
|---|---|---|
| `name` | yes | 1–64 chars, `a-z0-9-` only, no leading/trailing hyphen, no `--`, **must equal the parent directory name** |
| `description` | yes | 1–1024 chars, non-empty. What it does **and** when to use it (§2) |
| `license` | no | A license name or the name of a bundled license file. Keep it short |
| `compatibility` | no | ≤500 chars. Environment requirements (needs network, needs `git`/`docker`, intended product). Most skills do not need it |
| `metadata` | no | Free-form string map. Where `source` and `version` live for drift detection |
| `allowed-tools` | no | Experimental, support varies. Omit from portable skills |

House block, copy-paste and edit:

```markdown
---
name: <skill-name>
description: <what it does + when to use it + the words a user would say. One paragraph.>
license: Apache-2.0
metadata:
  source: <org>/<repo>
  version: 0.1.0
---
```

**Why `name` must equal the directory.** The loader discovers skills by walking directories
and validates that the declared name matches the one it found; a mismatch makes the skill
invisible or hard-fails the validator, with no error at the moment a user needed it. It
also means renaming is a two-file edit — directory and frontmatter, same commit — and that
the directory name is itself a trigger token users type (`skills/<pack>/<name>/`).

**Name it the way a user names the job.** `database-migrations`, not `migration-utils`;
`review-plan`, not `plan-helper`. Verb-noun for procedures, domain-noun for reference
material. The name is short, kebab-case, and unabbreviated — abbreviations lose matches.

**Nothing tool-specific in frontmatter.** `model`, `tools`, `allowed-tools`,
`disallowed-tools`, `argument-hint`, `arguments`, `user-invocable`,
`disable-model-invocation`, `paths`, `context`, `hooks`, `when_to_use` are vendor
extensions. One agent reads them, the next either ignores them or rejects the file. A
portable skill carries `name`, `description`, `license`, `metadata` and nothing else.

## 2. The description is the product

The loading model is why. Agents load skills progressively:

| Tier | What is loaded | When | Budget |
|---|---|---|---|
| Metadata | `name` + `description` of **every** installed skill | Always, at startup | ~100 tokens per skill |
| Instructions | The whole `SKILL.md` body | On activation | <5000 tokens recommended |
| Resources | `references/`, `scripts/`, `assets/` files | Only when the body sends the agent there | Unbounded, pay-per-use |

So the description competes for a decision made with zero knowledge of the body, against
every other installed skill, in a context the user never sees. Write it last, revise it
most, and test it (§6).

### 2.1 The formula

One paragraph, four parts, in this order:

1. **What it does** — concrete capabilities, named artifacts, real nouns. Not "helps with".
2. **When to use it** — the situations, phrased from the user's side of the conversation.
3. **The words a user would actually say** — quoted trigger phrases, including the sloppy
   and the impatient ones ("it doesn't work", "the deploy is red").
4. **A non-lexical fallback** — a condition that fires when the vocabulary does not (§2.3).

Add a negative clause when a sibling skill is close enough to be confused with this one.

### 2.2 Trigger engineering

- **Use the user's vocabulary, not your architecture's.** Users say "the pipeline is
  broken", not "the orchestration layer returned a non-terminal state". Harvest real
  phrasings from issues, support threads and your own transcripts.
- **Name the artifacts.** File names, extensions, command names and error strings appear
  verbatim in prompts and are high-precision triggers: `SKILL.md`, `evals.json`,
  `Chart.yaml`, `ORDER_MISMATCH`.
- **Carry synonyms for the same job.** "author", "write", "create", "draft", "set up".
  Each is a separate lexical shot at the same intent.
- **For a bilingual audience, carry both languages' tokens, paired.** Users switch language
  mid-sentence and type the native word for the domain object even in an English session.
  Keep the description's prose in English and let the other language appear as data in
  guillemets: `… (they may say «отчёт», «выгрузка», "report", "export") …`. The same applies
  to a product name that has a transliterated and a native form — carry both spellings.
- **Disambiguate near neighbours explicitly.** If two skills both mention "review", the
  descriptions must say which one owns diffs and which one owns plans. Users lose more to
  the wrong skill loading than to none loading.
- **Do not stuff.** A keyword list with no "when" reads as noise and mistriggers; the ceiling
  is 1024 characters and a good description usually lands at 400–800.

### 2.3 Non-lexical fallbacks

The strongest trigger is often not a word at all. Add a clause of the form *"Also use this
when X is present in the session, even if the user never says the name"*:

| Signal | Clause to add |
|---|---|
| The skill drives a tool server | "Also use when the `<product>` tools (`list_items`, `create_item`, `publish_item`, …) are available in the session and the task involves <domain>" |
| The skill governs a file type | "Also use whenever a `SKILL.md` or `evals/evals.json` is being read or edited" |
| The skill governs a directory | "Also use when work touches `migrations/` or `charts/`" |
| The skill is the project's convention | "Also use before writing any new <thing> in this repository" |

This is what rescues the case where the user asks for the job in words the skill's author
never imagined — the tools, the open file or the target directory say what the sentence
did not.

### 2.4 Diagnosing a description

| Symptom | Cause | Fix |
|---|---|---|
| Never triggers | Description states what it *is*, not when to use it | Add the "when", quoted user phrasings, and a non-lexical fallback |
| Triggers only when the user names the skill | No domain vocabulary | Harvest real prompts; add synonyms and artifact names |
| Wrong sibling loads | Two overlapping descriptions | Add the ownership boundary to both, and a negative clause |
| Triggers everywhere | Generic verbs ("helps", "manages", "improves") with no scope | Replace with the specific nouns; state the scope boundary |
| Loads but the agent ignores it | The body is advisory prose | Rewrite the body as imperative rules with a definition of done (§3) |

Poor: `description: Helps with database work.`
Good: `description: Write and review PostgreSQL migrations — forward-only files, expand/contract for column changes, index creation without locking writes, and the rollback note every migration carries. Use when adding or changing a table, when a migration failed halfway, or when the user says "add a migration", "alter the schema", "the migration is stuck", "rollback". Also use whenever a file under migrations/ is being edited.`

## 3. The body

**Budget: under 500 lines.** Past that, an activated skill crowds out the task it was loaded
for. Depth goes in `references/*.md` beside `SKILL.md`, one level deep, linked relatively,
one focused file per subject — those are loaded only when the body points at them.

| Put in the body | Put in `references/` |
|---|---|
| The rules that change behaviour every time | Full field/parameter tables, enumerations |
| The procedure, phase by phase | Long worked examples, transcripts |
| The lookup tables an agent needs mid-task | Background, rationale, history |
| The definition of done | Per-variant detail most runs never need |

Shape rules, in order of how much they matter:

1. **Open with the core rule in bold.** One sentence the agent must not violate. If a reader
   remembers nothing else, that is the sentence.
2. **State the scope boundary explicitly**, in the opening paragraph: "This skill defines
   only … It does not define …". Skills without a stated boundary sprawl on every edit and
   start overlapping their neighbours.
3. **Procedures are numbered phases**, each phase ending in checkbox items that are
   observable, not aspirational (`- [ ] make check passes`, not `- [ ] code is clean`).
4. **Lookup material is a table.** Symptom → cause → action; error → meaning → what to do;
   capability → concrete choice. Agents extract from tables reliably; they skim prose.
5. **Write imperative present tense, addressed to the agent.** "Read the outline before
   editing" — not "you may want to consider reading". Hedged prose is ignored under load.
6. **Show the artifact.** A copy-paste skeleton beats three paragraphs describing it.
7. **Mark real incidents, and only real incidents.** Reserve one marker (this library uses
   `[!]`) for a rule whose violation caused an actual production failure, and say what
   happened in one clause. Decorative use destroys the signal permanently — once every
   third rule is marked, the marker means "the author was emphatic".
8. **Be honest about maturity.** Prefix a claim you have not executed with `Verify:` and a
   deliberate-looking oddity with `Not an issue:`. A skill that quietly asserts an untested
   path is worse than one that admits the gap.
9. **End with a definition of done** the agent can self-check before reporting.

## 4. Portability

A skill is written once and installed into projects you will never see, next to skills you
did not write, under agents you did not test.

- **Soft references to other skills.** "If the `<other-skill>` skill is installed, follow
  it; otherwise follow the project's own conventions." Hard by-name references are safe only
  between skills that always ship together. Never reference a skill that does not exist — a
  dangling name sends the next agent hunting for a file that was never there.
- **No stack assumptions outside a stack-specific skill.** Say "the build command produces
  the artifacts", not "the Go binary compiles". A generic skill that assumes a language is a
  generic skill that is wrong half the time.
- **Layer generic → vendor → project.** Generic skills describe the pattern against named
  capabilities (`SECRET_MANAGER`, `MANAGED_PG`, `REGISTRY`, …); a vendor skill maps every
  capability to a concrete service and carries that vendor's traps; the project supplies the
  rest. The acceptance test: **adding a new vendor must change zero generic skills.** If it
  does not hold, the capability contract is wrong and fixing it there is the actual change.
- **End with `## Project delta`** — the explicit list of what the consuming repo must supply
  (namespace, module prefix, canonical document set, review bar). This is how a skill stays
  generic without becoming vague, and it gives the installing agent a checklist.
- **Content policy for anything public.** No hostnames, cluster or resource ids, namespaces,
  IP addresses, tokens, absolute local paths, live production URLs, verbatim customer copy,
  or anything identifying a real person. Use labelled placeholders — `<service>`,
  `example.com`, `my-cluster`. Concrete examples are good; concrete *real* examples are a
  leak, and a leak in a public library is permanent.
- **One prose language.** Pick the library's language and keep every instruction, heading and
  explanation in it, including in skills about another language — those are written *in*
  the library language *about* the other one, which appears only as data.

## 5. Patterns that make a skill measurably better

These are the behaviours graders reward, and the ones baselines without the skill miss.

- **Define behaviour when the preconditions are absent.** If the skill drives a tool server,
  an API or a cluster that may not be connected, say so up front: give the exact setup path
  **and** do the work anyway, in the form that becomes one call once the connection exists.
  A skill that stalls on a missing precondition scores zero on the case that matters most —
  the user's first session.
- **Ship an error table**: error or symptom → what it means → what to do next. This is the
  single highest-value block in a tool-driving skill; without it the agent invents recovery.
- **Ban fabricated completion.** Never report an action as performed when it was only
  drafted. When a batch call returns per-item results, report exactly which items failed and
  why — a partial success summarised as success is the most expensive lie a skill can teach.
- **Read before editing.** Fetch the current state and address objects by their real
  identifiers; never reuse an id from earlier in the conversation if the object may have
  changed underneath.
- **Gate irreversible and public actions** on an explicit user request — deletion,
  publishing, anything that leaves the workspace. Say it in the skill; the agent will not
  infer it.
- **Never route a credential through the conversation.** Give the user the command to run
  themselves rather than asking them to paste a token into chat.

## 6. Evals — proving the skill helps

Complex or judgment-heavy skills ship `evals/evals.json`. Convention skills may skip evals
but must still pass the library's validator.

**Why bother.** In one measured skill, three cases, run with and without the skill: pass rate
100% ± 0 with the skill against 93% ± 12 without, and **token use fell by about a third**
(≈38.2k vs ≈58.6k mean tokens per case) at slightly lower wall-clock. The skill won on cost
because it hands the agent the contract instead of forcing it to reconstruct one — both
baseline runs went source-archaeology and compiled throwaway harnesses to validate their own
output. Evals catch quality *and* cost regressions; the cost delta is usually the larger and
the more stable of the two.

### 6.1 `evals.json`

```json
{
  "skill_name": "<skill-name>",
  "evals": [
    {
      "id": 0,
      "name": "cold-start-happy-path",
      "prompt": "<written the way a real user types it — lowercase, terse, no jargon from the skill>. Save your final answer into the output directory you were given: the prose as response.md and the structured artifact as result.json.",
      "expected_output": "<one paragraph naming every observable property the answer must have: which artifact, which fields, which defaults, which claims it must NOT make>",
      "files": []
    },
    {
      "id": 1,
      "name": "edit-existing-artifact",
      "prompt": "<a modify-what-exists task, which forces read-before-edit and real identifiers>. Save your answer as response.md and the changed artifact as result.json.",
      "expected_output": "<...>",
      "files": ["fixtures/existing-artifact.json"]
    },
    {
      "id": 2,
      "name": "negative-no-fabrication",
      "prompt": "<asks for something that cannot be completed here — no connection, missing source material, or an action the skill must refuse>",
      "expected_output": "States plainly that it cannot complete the action and what is missing; does not claim the action was performed; invents no field names, identifiers, URLs or facts; offers the path that would make it possible.",
      "files": []
    }
  ]
}
```

Rules for the cases:

- **Write prompts as users write them** — sloppy, abbreviated, in whichever language the
  audience uses. A prompt that quotes the skill's own vocabulary tests nothing but itself.
- **Ask for file artifacts, not only prose.** Requiring `response.md` plus a structured
  artifact makes assertions mechanically checkable (counts, field presence, valid JSON)
  instead of a judgement call about a paragraph.
- **At least one negative case, always.** The correct behaviour is to refuse, to ask, or to
  not fabricate. Skills reliably make agents more confident; the negative case is what stops
  that from becoming more confidently wrong.
- **`files`** carries fixtures the case needs — an existing artifact to edit, source notes to
  ground answers in. Grounding cases ("use only facts from this input") are how you test
  anti-invention.

### 6.2 Assertions

`expected_output` is a paragraph; a run is graded against **atomic assertions** expanded from
it, one per checkable property, stored beside the case:

```json
{
  "eval_id": 0,
  "eval_name": "cold-start-happy-path",
  "prompt": "<the exact prompt as sent>",
  "assertions": [
    "Names the correct entry point and the exact command needed to connect",
    "Produces a well-formed artifact: <n> sections, every item carrying <field> and <field>",
    "Relies on positional defaults (no explicit <field>) or values that are strictly ascending",
    "At least two items carry <optional-field> where variation is expected",
    "Does not claim the artifact was actually created"
  ]
}
```

- **One property per assertion.** "Correct structure and correct tone" is two assertions and
  will be graded as one coin flip.
- **Make each independently checkable, ideally countable.** Good evidence reads
  "26 of 32 items carry the optional field" or "0 of 32 set an explicit value"; bad evidence
  reads "looks right".
- **Separate discriminating assertions from regression guards.** Some will pass in every
  configuration (anti-fabrication often does); keep them — they are what catches a future
  regression — but do not expect them to produce a delta. The assertions worth adding are
  the ones only the skill's own knowledge can satisfy. In the measured run, the single
  failing assertion anywhere was exactly the gap the skill existed to close.
- **Do not assert the skill's sentences back at it.** Assert the observable outcome, not that
  the answer contains a phrase from the body.

### 6.3 The A/B run

1. **Two configurations per case**: `with_skill` (the skill installed) and `without_skill`
   (identical prompt, no skill). Everything else identical — same model, same prompt, same
   fixtures, same output contract.
2. **Repeat each configuration at least three times.** A single run cannot distinguish a
   skill from luck; in the measured run, baseline pass rate varied by case while the
   with-skill runs did not.
3. **Run in a clean working directory.** `Verify:` in the measured run both baselines
   executed inside the source repository and read the implementation to ground themselves —
   endpoints, field names, limits — which a real user's machine does not have. That
   contamination flattered the baseline, so its +7-point pass-rate deficit is a *lower
   bound* on the skill's value, and the token delta is the more trustworthy signal. If you
   cannot isolate the environment, record the contamination in the notes and discount
   accordingly.
4. **Capture per-run**: the outputs, a grading file, and timing/token counts.

```
<skill>-workspace/
└── iteration-1/
    ├── eval-0-<name>/
    │   ├── eval_metadata.json          # prompt + atomic assertions (§6.2)
    │   ├── with_skill/run-1/{outputs/, grading.json, timing.json}
    │   └── without_skill/run-1/{outputs/, grading.json, timing.json}
    ├── benchmark.json                  # every run + rollup + analyst observations
    └── benchmark.md                    # the table a human reads
```

Keep the workspace out of publication globs — run transcripts carry whatever the prompts
carried.

### 6.4 Grading

Grade each assertion independently and **cite evidence** — a count, a quoted line, a field
check. An ungrounded `passed: true` is indistinguishable from a grader hallucination.

```json
{
  "expectations": [
    {"text": "<assertion>", "passed": true,  "evidence": "<count, quote or field check>"},
    {"text": "<assertion>", "passed": false, "evidence": "<what was missing, concretely>"}
  ],
  "pass_rate": 0.5,
  "summary": {"pass_rate": 0.5, "passed": 1, "failed": 1, "total": 2}
}
```

`timing.json` is `{"total_tokens": <n>, "duration_ms": <n>, "total_duration_seconds": <n>}`.

### 6.5 The benchmark rollup

`benchmark.json` carries metadata (skill name, executor and analyser models, timestamp,
cases run, runs per configuration), every run, and a summary:

| Metric | With skill | Without skill | Delta |
|---|---|---|---|
| Pass rate | mean ± stddev | mean ± stddev | signed |
| Time (s) | mean ± stddev | mean ± stddev | signed |
| Tokens | mean ± stddev | mean ± stddev | signed |

Reading it:

- **Tokens is the metric that moves.** A skill that hands over the contract removes an
  exploration phase; expect double-digit percentage savings, and treat a *token increase*
  with no pass-rate gain as a defect in the skill, not a cost of quality.
- **Compute variance across repeats of the same case.** A stddev computed across different
  cases measures case difficulty, not stability — an easy mistake when the rollup lumps all
  runs into one pool, and it inflates the number that a reader will quote.
- **A near-perfect baseline means the cases are too easy or the environment is
  contaminated.** Add a case that requires knowledge only the skill has.
- **Record analyst observations in prose** next to the numbers: what contaminated a run,
  which assertions never discriminate, which of the skill's signature moves actually showed
  up in the with-skill outputs. That paragraph is what makes the next iteration cheap.

### 6.6 The iteration loop

1. Run the suite. 2. Read only the failed assertions and the token delta. 3. Change **one**
thing in the skill — usually the description (triggering), one rule (behaviour), or a moved
section (context cost). 4. Bump `metadata.version`, record what changed. 5. Re-run the same
cases into `iteration-2/`. Never edit the cases and the skill in the same iteration; you
lose the ability to say which one moved the number.

## 7. Definition of done

- [ ] Directory name equals frontmatter `name`; both are lowercase kebab-case.
- [ ] Frontmatter carries `name`, `description`, `license`, `metadata.source`,
      `metadata.version` — and nothing tool-specific.
- [ ] Description ≤1024 chars and contains: what, when, quoted user phrasings, a non-lexical
      fallback, and a boundary against the nearest sibling skill.
- [ ] Body under 500 lines; anything deeper is in `references/*.md`, one level deep, linked
      relatively, and actually exists.
- [ ] The opening states the core rule and the scope boundary, including what the skill does
      **not** do.
- [ ] Procedures are numbered phases with observable checkboxes; lookup material is tables.
- [ ] Every cross-skill reference is soft, and every referenced skill exists.
- [ ] No stack, vendor or project assumption that the skill's own layer does not own; a
      `## Project delta` section names what the consuming repo supplies.
- [ ] No hostnames, ids, IPs, tokens, absolute local paths, production URLs, or personal
      data. Placeholders only.
- [ ] `[!]`-style markers used only for rules tied to a real incident.
- [ ] Unverified claims carry `Verify:`.
- [ ] Judgment-heavy skill: `evals/evals.json` exists, includes a negative case, and has been
      run with-skill versus without-skill at least once.
- [ ] The library's validator passes.

## 8. Maintenance

- **Bump `metadata.version` on every content change** and add a changelog entry. Installed
  copies carry the version; that is what makes drift detectable.
- **Upstream-first.** An improvement discovered while using an installed copy is made in the
  library and re-installed. Never hand-edit an installed copy — the edit is invisible to
  every other consumer and the next install silently reverts it.
- **Re-run the evals after any behavioural edit**, and after a model upgrade. A skill written
  against one model's failure modes can become dead weight against the next one's; the token
  column tells you before the pass-rate column does.
- **Delete rather than deprecate.** A skill nobody triggers still costs its description in
  every session.

If the `documentation-standards` skill is installed, a skill's own docs follow its rules; if
`mcp-server-authoring` is installed, pair it with this one when the skill drives a tool
server. Otherwise follow the project's own conventions.

## Project delta

The consuming repo supplies:

- **Where skills live** and the pack or category naming (`skills/<pack>/<name>/SKILL.md` here).
- **The `metadata.source` string** stamped into every skill.
- **The validator command** and whether it runs in CI.
- **The incident-marker convention** — which marker means "this caused a real outage".
- **The eval bar** — which skills must ship evals, how many runs per configuration, which
  models execute and grade, and where the eval workspace lives (and that it is excluded from
  publication).
- **The audience's vocabulary** — the product names, native-language tokens and artifact
  names that belong in descriptions, plus any term that must never appear.
- **The review bar** — who approves a new skill and what a change requires beyond the
  definition of done above.
