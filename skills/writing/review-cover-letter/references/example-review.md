# Worked reviews — end to end

Three self-contained examples: a full review with every input present, the same rubric on an
English-language letter, and a degraded review where the CV was not supplied. All inputs are
invented. The posting is a paraphrase, not a copy of any real listing, and no example
describes a real person.

Framing prose is English throughout. Where the letter under review is Russian, the Russian
text appears only as **data** — quoted spans inside `evidence`, `claim` and fix lines.

---

## 1. Full review — junior, technical, `portal_note` with a keyword gate

### Inputs

**Posting (paraphrased).** Junior Python developer at a fintech, hybrid. Requirements:
Python, FastAPI or Django, basic SQL, Git. Nice to have: Docker. **Instruction:** the note
must begin with the word «питон» and state the date the candidate can start.

**CV (facts).** Fourth-year computer-science student, no commercial experience. Personal
projects: a chat bot in Python (aiogram); a coursework REST API on FastAPI with SQLite.
Knows Git. No Docker, no Kubernetes, no leadership experience.

**Message under review.**

> Здравствуйте! Я коммуникабельный, стрессоустойчивый и ответственный разработчик. Имею
> богатый опыт коммерческой разработки на Python и руководил командой из 5 человек. Мой
> опыт позволяет мне быть максимально полезным вашей компании, и я уверен, что я идеальный
> кандидат на эту позицию. Я работал с Django, FastAPI, Docker и Kubernetes на
> высоконагруженных проектах. Надеюсь на возможность обсудить.

### Scorecard

```json
{
  "schema_version": "1.0",
  "case_id": "junior-portal-keyword-01",
  "inputs_seen": ["message", "posting", "cv"],
  "detected_params": {
    "channel": "portal_note",
    "locale_mode": "ru_RU",
    "instruction_mode": "keyword_gate",
    "relationship_temperature": "cold",
    "seniority": "junior",
    "candidate_story": "no_direct_experience",
    "industry_mode": "tech",
    "proof_assets": ["portfolio", "education_only"],
    "tone_register": "enthusiastic",
    "cta_strength": "soft",
    "truth_mode": "resume_plus_job_post"
  },
  "scores": {
    "instruction": "fail",
    "tailoring": "fail",
    "evidence": "fail",
    "length": "pass",
    "register": "fail",
    "cta": "warn",
    "honesty": "fail"
  },
  "findings": [
    {
      "rule_id": "INSTR-1",
      "rule": "instruction_first",
      "severity": "critical",
      "status": "fail",
      "evidence": "<absent>",
      "why": "The posting requires the word «питон» as the opening and a start date; neither appears.",
      "fix_instruction": "Begin the message with the exact word «питон», then state a concrete start date, before any pitch.",
      "param": "instruction_mode=keyword_gate"
    },
    {
      "rule_id": "HON-1",
      "rule": "no_fabrication",
      "severity": "critical",
      "status": "fail",
      "evidence": "Имею богатый опыт коммерческой разработки на Python и руководил командой из 5 человек.",
      "why": "The CV is a student with no commercial experience and no leadership role — both claims are invented.",
      "fix_instruction": "Delete the commercial-experience and team-lead claims; rebuild the sentence on the two real projects (the aiogram chat bot and the FastAPI coursework API).",
      "param": "candidate_story=no_direct_experience"
    },
    {
      "rule_id": "HON-1",
      "rule": "no_fabrication",
      "severity": "critical",
      "status": "fail",
      "evidence": "Я работал с Django, FastAPI, Docker и Kubernetes на высоконагруженных проектах.",
      "why": "Only FastAPI is in the CV, in a coursework project. Django, Docker, Kubernetes and the high-load claim are not.",
      "fix_instruction": "Keep only FastAPI and say it was coursework; remove Django, Docker, Kubernetes and «высоконагруженные проекты». To signal Docker interest, write «изучаю», never «работал».",
      "param": "truth_mode=resume_plus_job_post"
    },
    {
      "rule_id": "PROOF-4",
      "rule": "open_on_concrete",
      "severity": "high",
      "status": "fail",
      "evidence": "Я коммуникабельный, стрессоустойчивый и ответственный разработчик.",
      "why": "Opens on trait words instead of the strongest concrete project.",
      "fix_instruction": "Open the body on the strongest real artifact — the chat bot on aiogram or the FastAPI coursework API — with what it does.",
      "param": "seniority=junior"
    },
    {
      "rule_id": "PROOF-1",
      "rule": "proof_over_traits",
      "severity": "high",
      "status": "fail",
      "evidence": "коммуникабельный, стрессоустойчивый и ответственный",
      "why": "Trait words with no supporting example.",
      "fix_instruction": "Delete the trait list, or replace it with one concrete behaviour observable in the projects."
    },
    {
      "rule_id": "REG-3",
      "rule": "no_overclaim",
      "severity": "high",
      "status": "fail",
      "evidence": "я уверен, что я идеальный кандидат на эту позицию",
      "why": "Unevidenced hype.",
      "fix_instruction": "Delete the «идеальный кандидат» claim; let one concrete project carry the point."
    },
    {
      "rule_id": "REG-5",
      "rule": "no_editorializing",
      "severity": "high",
      "status": "fail",
      "evidence": "Мой опыт позволяет мне быть максимально полезным вашей компании",
      "why": "Leading editorializing: states what the experience allegedly allows instead of showing it.",
      "fix_instruction": "Remove the clause and state the fact — what was built and what it does."
    },
    {
      "rule_id": "TAIL-1",
      "rule": "tailor_per_job",
      "severity": "high",
      "status": "fail",
      "evidence": "<whole message>",
      "why": "Nothing anchors to this role, product or stack; the text would survive in any application.",
      "fix_instruction": "Add one sentence tying a real project to this fintech backend role — e.g. the FastAPI coursework API to the backend tasks the posting names."
    },
    {
      "rule_id": "CTA-2",
      "rule": "no_generic_close",
      "severity": "medium",
      "status": "warn",
      "evidence": "Надеюсь на возможность обсудить.",
      "why": "Stock close with nothing concrete attached.",
      "fix_instruction": "Replace the stock close with a concrete low-friction offer tied to a real artifact — the project code — plus a scheduling question."
    }
  ],
  "claim_audit": [
    { "claim": "Имею богатый опыт коммерческой разработки на Python", "bucket": "forbidden_fabrication", "note": "student CV, no commercial experience", "rule_id": "HON-1" },
    { "claim": "руководил командой из 5 человек", "bucket": "forbidden_fabrication", "note": "no leadership role in the CV", "rule_id": "HON-1" },
    { "claim": "работал с FastAPI", "bucket": "evidence_backed", "note": "coursework REST API on FastAPI with SQLite", "rule_id": "PROOF-2" },
    { "claim": "работал с Django, Docker и Kubernetes на высоконагруженных проектах", "bucket": "forbidden_fabrication", "note": "none of these appear in the CV", "rule_id": "HON-1" },
    { "claim": "коммуникабельный, стрессоустойчивый и ответственный", "bucket": "unverifiable", "note": "traits with no example; not checkable against any source", "rule_id": "PROOF-1" }
  ],
  "overall_verdict": "block",
  "summary": "Blocked: the note ignores the mandatory «питон» keyword and start-date instruction, and fabricates commercial experience, a team-lead role and a Django/Docker/Kubernetes high-load stack the student CV does not support. Highest-leverage fix: satisfy the instruction, then rebuild the body on the two real projects.",
  "fix_brief": [
    "1. [INSTR-1] Begin with «питон» exactly, then a concrete start date, before the pitch.",
    "2. [HON-1] Remove «богатый опыт коммерческой разработки» and «руководил командой из 5 человек»; rebuild on the aiogram chat bot and the FastAPI coursework API.",
    "3. [HON-1] Keep only FastAPI (coursework); remove Django, Docker, Kubernetes and «высоконагруженные проекты».",
    "4. [PROOF-4] Open the body on the strongest real project, not on traits.",
    "5. [PROOF-1] Drop «коммуникабельный, стрессоустойчивый, ответственный» or back it with one example.",
    "6. [REG-3] Delete «я идеальный кандидат».",
    "7. [REG-5] Delete «Мой опыт позволяет мне быть максимально полезным».",
    "8. [TAIL-1] Add one sentence tying a real project to this fintech backend role."
  ]
}
```

### What the example is for

`length` is `pass` — roughly six sentences, inside the `portal_note` band. That is the
point: a reviewer that only counted words would report a tidy letter and miss the three
`critical` findings that actually block it. Note also that `CTA-2` is `medium` and therefore
absent from `fix_brief`: the brief carries `critical` and `high` only, most-blocking first.

---

## 2. The English branch — `email_cold`, mid-level, career change

Same rubric, different `locale_mode`, and two rules whose severity moves with it.

**Posting (paraphrased).** Data analyst at a mid-size retailer, hybrid, one location. No
instruction beyond "apply with a CV". **CV (facts).** Six years in operations management;
completed a part-time analytics certificate; SQL and spreadsheet modelling used in the
current role; no analyst job title.

**Message under review.**

> Dear Hiring Manager, I am a 41-year-old married father of two and I am writing to apply
> for the Data Analyst position. While I lack direct analytics experience, I am a fast
> learner and a team player, and my background demonstrates my strong analytical
> capability. I have always dreamed of working for a company like yours. My salary
> expectation is competitive. I look forward to discussing.

Findings, abbreviated to the ones the locale and the situation drive:

| `rule_id` | Severity | Evidence | Why |
| --- | --- | --- | --- |
| `HON-5` | `critical` | "I am a 41-year-old married father of two" | Age, marital status and dependants volunteered. In this locale, volunteering protected characteristics is an anti-discrimination hazard, not merely unwelcome — severity is raised from `high`. |
| `REG-6` | `high` | "While I lack direct analytics experience" | A soft gap confessed instead of bridged. The career-change story (§4) calls for naming the transferable ground — SQL and modelling already used in operations — not the deficit. |
| `REG-5` | `high` | "my background demonstrates my strong analytical capability" | Editorializing: a claim about the evidence in place of the evidence. |
| `PROOF-1` | `high` | "a fast learner and a team player" | Trait words, no example. |
| `REG-3` | `high` | "I have always dreamed of working for a company like yours" | Unevidenced hype with no anchor in the posting, and the phrasing is generic to the point of self-refutation. |
| `HON-6` | `high` | "My salary expectation is competitive" | Compensation raised unprompted; the posting did not ask. |
| `CTA-2` | `medium` | "I look forward to discussing" | Stock close, nothing concrete. |
| `TAIL-1` | `high` | `<whole message>` | No product, team or requirement from the posting appears anywhere. |

`overall_verdict: "block"` on `HON-5` alone. `claim_audit` marks "my background demonstrates
my strong analytical capability" as `safe_inference` **overstated** — the CV supports SQL and
modelling in an operations context, not a general analytical capability claim — which is
`HON-2` at `high`, not a fabrication. The distinction matters: a fabrication is deleted, an
overstated inference is narrowed to what the CV supports.

---

## 3. The degraded case — no CV supplied

Same message as example 1, but the reviewer was given only the message and the posting. The
instruction, tailoring, length, register and CTA families are unaffected, and so is most of
the evidence family — only `PROOF-2` (numbers traceable to a source) needs the CV. The
honesty family cannot be settled at all.

The block below is **abridged**: it shows only the fields that change. `detected_params`,
the findings that do not depend on the CV and `fix_brief` carry over unchanged from example
1, except that `seniority` and `candidate_story` drop to `"unknown"` — both were inferred
from the CV, and a parameter that cannot be inferred is never guessed. A real scorecard
always emits every required field of the schema.

```json
{
  "schema_version": "1.0",
  "inputs_seen": ["message", "posting"],
  "inputs_missing": ["cv"],
  "scores": {
    "instruction": "fail", "tailoring": "fail", "evidence": "fail",
    "length": "pass", "register": "fail", "cta": "warn", "honesty": "warn"
  },
  "findings": [
    {
      "rule_id": "HON-1",
      "rule": "no_fabrication",
      "severity": "high",
      "status": "unverifiable",
      "evidence": "Имею богатый опыт коммерческой разработки на Python и руководил командой из 5 человек.",
      "why": "No CV was supplied, so no claim in this message can be traced to a source.",
      "fix_instruction": "Supply the CV or profile facts so the commercial-experience and team-size claims can be checked; do not treat them as accepted."
    }
  ],
  "claim_audit": [
    { "claim": "Имею богатый опыт коммерческой разработки на Python", "bucket": "unverifiable", "note": "no CV provided", "rule_id": "HON-1" },
    { "claim": "руководил командой из 5 человек", "bucket": "unverifiable", "note": "no CV provided", "rule_id": "HON-1" }
  ],
  "overall_verdict": "block",
  "summary": "Blocked: the note fails the mandatory «питон» and start-date instruction, which is decisive on its own. Honesty could not be assessed — no CV was supplied, so every factual claim is unverifiable rather than accepted; seniority and candidate_story were left unknown for the same reason. Send the CV for a complete review."
}
```

The shape to copy: a missing input never softens a verdict that another family already
earned — `INSTR-1` is still `critical`, so the verdict is still `block`, not `revise`.
Degradation only removes what can be *checked*. `honesty` is `warn`, never `pass`;
`evidence` stays `fail` because `PROOF-1` and `PROOF-4` never needed the CV; the verdict can
never be `send_ready`; and the missing input is named in `summary` and in every
`fix_instruction` that depends on it. The failure mode this prevents is a reviewer that,
lacking a CV, quietly reports a fabricating letter as clean.
