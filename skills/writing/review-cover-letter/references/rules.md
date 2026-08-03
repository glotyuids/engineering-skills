# Cover-letter review rules — the coded taxonomy

The rubric applied by the [`review-cover-letter`](../SKILL.md) skill. Every rule has a
stable ID; findings cite the ID, so aggregated review data stays comparable across
corpora and across time. Rule IDs are append-only: retire a rule by marking it deprecated
here, never by reusing its number.

This file is locale-neutral. It branches on a detected `locale_mode` but does not carry
any one market's norms — those belong in a locale skill (for Russian-language letters,
`ru-market-job-application-norms` if it is installed) or in the project delta.

> This taxonomy **reviews**; it never rewrites. Each rule's fix is phrased so it can be
> dropped verbatim into a rewriter prompt as a must-fix line.

## How to read evidence strength

- **[strong]** — stated concretely in hiring-platform documentation, in live posting
  requirements, or in major career-centre / ATS-vendor guidance.
- **[common]** — stable advice across authoritative sources, no controlled proof.
- **[contested]** — credible sources disagree, or a platform contradicts itself. Default
  to the safer target and flag it; do not assert either side.

A rule's strength changes how a finding is *worded*, never whether it is *recorded*. A
`[contested]` rule produces a finding that names the disagreement ("platforms differ; the
safe target is X") rather than a verdict about the truth.

## Severity scale

| Severity | Meaning | Maps to verdict |
| --- | --- | --- |
| `critical` | Honesty breach, unmet **explicit** employer instruction, leaked private or protected data. | `block` — must never be reported as ready to send |
| `high` | Generic/template text, overclaim, wrong length for the channel, no concrete proof, language mixing, editorializing, volunteered gap confession. | `revise` — rewrite before sending |
| `medium` | Weak or absent CTA, register slip, mild CV duplication. | `revise` — should fix |
| `low` | Polish: word economy, sentence rhythm, ordering. | `send_ready` with notes |

`critical` and `high` always land in the fix brief; `medium` and `low` are advisory.
`unverifiable` is a finding *status*, not a severity — an unverifiable check carries
`severity: high` and blocks `send_ready` without forcing `block`.

---

## 0. Parametric frame — detect before scoring

A review is parameter-conditioned: many rules only fire, or change severity, under a given
parameter. Detect these from the inputs first. When a value cannot be inferred, mark it
`unknown` and skip the rules gated on it rather than guessing — a guessed parameter
silently changes the rubric.

| Param | Values | Gates |
| --- | --- | --- |
| `channel` | `formal_letter`, `portal_note`, `questions_plus_note`, `board_chat_followup`, `speculative_letter`, `email_cold`, `email_warm`, `network_connect_note`, `network_inmail`, `messenger_dm`, `post_apply_dm` | length band, greeting, allowed CTA, formality (§2) |
| `locale_mode` | a market/language tag, e.g. `ru_RU`, `en_US`, `en_UK_EU` | greeting, length, directness, personal-data norms (§3) |
| `instruction_mode` | `none`, `explicit_question`, `keyword_gate`, `availability_gate`, `salary_gate`, `portfolio_gate`, `relocation_gate` | when not `none`, instruction compliance outranks persuasion (§1.A) |
| `relationship_temperature` | `cold`, `warm`, `referred`, `internal`, `post_apply` | opening and CTA (§4) |
| `seniority` | `junior`, `mid`, `senior_ic`, `lead_manager`, `executive` | which proof leads (§4) |
| `candidate_story` | `standard`, `career_change`, `gap_return`, `no_direct_experience`, `overqualified`, `step_up` | whether an explain-window is needed, and how early (§4) |
| `industry_mode` | `tech`, `creative`, `corporate_finance_ops`, `mass_blue_collar`, `academic` | tone, portfolio/code emphasis, length (§5) |
| `proof_assets` | `metrics`, `portfolio`, `github`, `case_studies`, `certs`, `education_only`, `none` | which evidence blocks may exist at all |
| `tone_register` | `formal`, `warm_professional`, `concise_direct`, `enthusiastic`, `chat_brief` | lexis, sentence length, close |
| `cta_strength` | `none`, `soft`, `specific_low_friction` | the last line (§1.F) |
| `truth_mode` | `strict_resume_only`, `resume_plus_job_post`, `resume_plus_user_context` | which claims may exist at all (§6) |

`truth_mode` widens the *source set* a claim may be traced to. It never widens what may be
invented: there is no value of any parameter under which a fabrication is allowed.

---

## 1. Core rubric

Each finding cites a rule ID. Default severities may be raised one notch by the channel,
locale or industry (an unmet keyword gate is always `critical`; humor is `high` in a
`formal_letter` and `low` under `industry_mode = creative`).

### A. Instruction compliance — highest leverage

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `INSTR-1` | Every explicit employer instruction in the posting is satisfied **before** any persuasive copy. | The letter ignores a required opening word, question, start date, relocation answer, contact handle, code/portfolio link, salary figure or employment-format answer. | `critical` | `instruction_mode != none` |
| `INSTR-2` | Each instruction is satisfied in the **exact requested form**. | "three to five bullets" answered as prose; "one sentence" answered with a paragraph; a requested artifact (a first-month plan) missing. | `high` | `instruction_mode != none` |
| `INSTR-3` | An instruction needing a fact the candidate lacks is **surfaced**, never invented. | The letter fabricates a value — years, level, certificate, availability — to clear a gate. | `critical` | `instruction_mode != none` |

**Why first:** postings routinely use the message field as an instruction-response field —
a keyword, a start date, a relocation answer, a link, a handle. A beautifully argued letter
that ignores "start your message with the word X" is auto-rejected before anyone reads the
argument. **[strong]** In some markets this is the dominant use of the field; a locale
skill supplies that frequency, but the rule holds everywhere a posting states one.

### B. Tailoring and relevance

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `TAIL-1` | Opening, two to three fit signals and the CTA are specific to **this** role and employer. | The letter would survive unchanged in another application — no role, employer, product or stack anchor. | `high` | always |
| `TAIL-2` | The letter **complements** the CV — context, motivation, one or two relevant cases, a career nuance — instead of restating it. | Paragraphs re-list CV bullets or job history. | `medium` | always |
| `TAIL-3` | Three to five key posting requirements mirrored in **natural** language. | Keyword stuffing, pasted posting sentences, hidden text, pseudo-ATS incantations. | `high` (stuffing) / `medium` (thin) | always |

Hiring platforms deliberately make per-application notes non-reusable so the message is not
a form letter; career centres require tailoring. **[strong]** Whether ATS software scans
letters for keywords is **[contested]** — one vendor says letters are parsed for keywords,
another says there is no auto-reject and decisions are human. Therefore: mirror naturally,
never stuff. Stuffing is a `high` finding under both readings.

### C. Evidence and substance

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `PROOF-1` | No empty trait-words without a concrete example. | "team player", "fast learner", "responsible", "stress-resistant" standing alone. | `high` | always |
| `PROOF-2` | Every metric, number and scope is traceable to the CV, the posting, or an explicit user fact. | An invented or rounded-up figure, a team size, or a scope misattribution (a portfolio-wide total pinned to one product). | `critical` | always (honesty; see `HON-2`) |
| `PROOF-3` | The letter routes early to artifacts — projects, stack, contribution, code, portfolio, impact. | A technical letter is an abstract essay with no path to evidence. | `high` | `industry_mode = tech` |
| `PROOF-4` | Opens on the single strongest **concrete** achievement — the hardest number or result. | Opens on a general experience summary ("my experience allows me to…"), a plea or apology, a self-label ("a strong candidate"), or a stock formula ("please consider my candidacy"). | `high` | `channel` is a letter, note or email |

Technical roles weigh demonstrable proof over prose; postings ask for code and projects;
platform guidance explicitly bans clichés and shows how to replace traits with
results. **[strong]**

### D. Length and scannability

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `LEN-1` | Length within the channel band (§2). | Outside the band — a one-page essay in a `portal_note`, a five-line note where a full letter is expected. | `high` (≥2× over) / `medium` | always |
| `LEN-2` | Scannable: short sentences, fast time-to-value, one idea per sentence. | Wall of text, buried lede, no fast "why I fit". | `medium` | always |

Platform guidance converges on five to six sentences or five to seven theses for a short
application note, and one page for a formal letter; shorter outbound messages get higher
reply rates. **[strong]**

### E. Register, tone and locale

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `REG-1` | Register matches the locale's business-correspondence default and the posting's own register: neutral greeting, correct address form, no slang or familiarity. | Casual greeting, familiar address form, slang or emoji in a formal or portal context. | `high` (formal/portal) / `low` (messenger, when the posting's tone signals it) | `locale_mode != unknown`; concrete forms come from the locale skill or project delta |
| `REG-2` | The whole message is monolingual in the artifact's locale; domain terms are rendered naturally, not pasted or code-switched. | A greeting or sign-off carried over from another language, language-mixed sentences. | `high` | always |
| `REG-3` | No unevidenced hype or self-comparison. | "I'm the ideal candidate", "I exceed all requirements", "I have always dreamed of working here" with no factual anchor, "better than other candidates". | `high` | always |
| `REG-4` | Humor and heavy creativity only when the posting's own tone signals it, or `industry_mode = creative`. | Jokes, memes or irony in a neutral corporate or formal context. | `high` (formal/corporate) / `low` (creative) | always |
| `REG-5` | No editorializing evidence into a competency claim. | Trailing ("…which demonstrates / reflects / confirms my skills", "speaks to my capability") or leading ("my experience allows me to…"). | `high` | always |
| `REG-6` | No volunteered confession of a soft, non-blocking gap inside the letter — bridge from a transferable strength instead. | "I understand I haven't worked in…", "while I lack…", "my background doesn't fully span…". | `high` | always |

`REG-5` and `REG-6` are the two rules generation pipelines fail most often: a model that is
asked to sound humble produces either a self-assessment ("which demonstrates my strong
engineering skills") or a pre-emptive apology. Both replace a fact with a claim about the
fact. A soft gap is bridged from strength; only a genuine hard blocker is surfaced, and
then through the channel, not confessed mid-letter. `REG-2` and `REG-5` are cheap to
enforce mechanically — a lint pass over trailing clauses and over script/charset mixing
catches most instances before a human reviews. **[strong]**

### F. CTA and closing

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `CTA-1` | Closes on a small, specific next step matched to `cta_strength`. | Demanding an urgent decision, supplication, or no close where one is expected. | `medium` | `cta_strength != none` |
| `CTA-2` | No stock close used as the only closing content. | "I look forward to discussing", "hoping for the opportunity to talk" with nothing concrete attached. | `medium` | always |

End on readiness to talk and a low-friction offer — a conversation starter, not "consider
me urgently". **[common]**

### G. Honesty boundary — binding, never weakened

A `critical` here forces `block`. If a project honesty policy or the `writing-honesty-gates`
skill is installed, these rules restate it and it wins on conflict.

| ID | Check | Violated when | Severity |
| --- | --- | --- | --- |
| `HON-1` | No fabricated facts, metrics, tools, employment, dates, titles, degrees, certificates or language fluency. | Any claim with no backing in the CV, the posting or an explicit user fact. | `critical` |
| `HON-2` | Every claim is traceable; each is classified into the three buckets (§6). | Asserting direct experience with X where the CV shows only adjacent or transferable fit. | `critical` (fabrication) / `high` (overstated inference) |
| `HON-3` | No private motivation exposed in a public message. | Burnout, a manager conflict, personal hardship, the raw private reason for leaving appears in the letter. | `critical` |
| `HON-4` | Hard blockers — work authorization, a mandatory licence or certificate — are not papered over by nice text. | The letter hides or spins a knockout requirement the candidate provably fails. | `critical` |
| `HON-5` | No protected or personal characteristics unless legally required and relevant. | Age, marital status, a photo reference, dependants, health, personal circumstances volunteered. | `high` where volunteering is merely unwelcome; `critical` in markets where it is an anti-discrimination hazard |
| `HON-6` | Salary, notice period and relocation appear only when explicitly asked for or supplied as a user fact. | Auto-inserted compensation or availability the user never provided. | `high` |

Lying is checked at interview, so a fabrication is not a risk the letter takes — it is a
risk it hands to the candidate. Recruiter surveys through 2026 show an active trust crisis
around AI-generated applications (§8), which makes verifiable specificity the single
strongest signal a letter can carry. **[strong]**

### H. Personal data and off-limits

| ID | Check | Violated when | Default severity | Applies when |
| --- | --- | --- | --- | --- |
| `PD-1` | No autobiography, family status, irrelevant hobbies or personal worries. | The letter drifts into life story or non-relevant personal detail. | `medium` | always |
| `PD-2` | No third party is identified without their consent. | A referrer, a former manager or a colleague is named where no permission was supplied. | `high` | always |

---

## 2. Channel matrix — length, structure, CTA, anti-patterns

Length bands are the review thresholds for `LEN-1`. A project may lock a narrower band
(project delta); when it does, the project band wins.

| `channel` | Real-world form | Purpose | Length band | Canonical structure | Register | CTA | Anti-patterns | Strength |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `formal_letter` | attached or pasted full letter | Readable narrative fit, especially where a letter is required. | **180–320 words**, or **≤1 page** | role and salutation → why this role/employer → one or two cases with numbers → why this employer → polite close | formal-professional | availability to talk | CV retelling, biography, flowery prose, empty traits | **[strong]** |
| `portal_note` | the short note field on a job board | Fast screen, and a signal that the posting was understood. | **4–6 sentences**, or **5–7 theses**; if a micro-task is set, exactly as required (sometimes one phrase) | greeting → role → two or three fit signals → one proof → short close; **an instruction overrides this structure** | concise business, dense | often just readiness to discuss; in micro-task mode a CTA may be absent | long essay, generic words, ignoring the instruction | **[strong]** |
| `questions_plus_note` | screening questions plus a note field | Answer the screening questions correctly first, then top up. | mandatory answers first, then **2–4 sentences** | satisfy the questions → short value summary → optional close | functional, plain | offer detail at interview | covering an unanswered question with pretty text | **[strong]** |
| `board_chat_followup` | in-platform chat after applying | Follow up, clarify, attach materials. | **1–3 short replies**, then to the point | reference the application → one clarifying line or attachment → easy contact | businesslike, conversational | a short question or next step | a second long letter instead of a concrete follow-up | **[strong]** |
| `speculative_letter` | no open posting | Create a reason to talk where no vacancy exists. | **80–150 words** | why writing → why this employer now → fit summary → low-friction ask | restrained-direct | "if a relevant role exists, happy to talk briefly" | mass-mailing tone, no named role or direction | **[common]** |
| `email_cold` | direct email to a relevant contact | Approach off the job board. | **100–200 words**, preferred ~130–140 | who you are and why this person → one or two fit points and one proof → small ask | businesslike | "worth sending cases?", "is 10–15 minutes convenient?" | long letter, generic subject, pasted posting | **[common]** |
| `email_warm` | referral or former-colleague intro | Use a warm path without burning it. | **60–120 words** | the referral in the first line, with the referrer's permission → why relevant → next-step ask | warm-professional | "what's the best way to apply?" | naming a referrer without permission; the referral as the only argument | **[common]** |
| `network_connect_note` | connection request note on a professional network | Explain why the request is not random. | **safe target ≤200 characters** — platform limits differ by account tier and change; verify | what is in common, why connect now | brief | minimal or none | a pitch, a long ask, a generic "I'd like to add you" | **[contested]** |
| `network_inmail` | direct outbound message to a non-connection | Meaningful outbound. | subject **≤200 characters**; body limit is large (~1900 characters) but **60–130 words** is the working target | reason for contact and profile trigger → goal, specific fit, why now → conversation starter | conversational-professional | one question or next step, not "consider me urgently" | long body, pasted posting, generic pitch, a second follow-up before any reply | **[strong]** on limits / **[common]** on style |
| `messenger_dm` | messenger, where the posting names a handle or the market runs on chat | Reach the hiring contact where they actually are. | **250–600 characters**, or **3–6 short lines** | context → role → one proof | concise, plain, links to code or projects | a binary next step: "send two or three cases, or call?" | formal-letter style, wall of text, aggressive follow-up, no context anchor | **[common]** |
| `post_apply_dm` | direct message after applying | Add one signal without duplicating the letter. | **40–90 words** | "I applied for role X" → one fact (stack, case, location, notice, relocation) → tiny offer | brief | "happy to send two cases or a code link" | re-sending the whole cover letter | **[common]** |

Character-limit rows are `[contested]` on purpose: platforms change limits and tier them by
account type. Review against the safe target and word the finding as "over the safe target",
not "over the limit", unless the current limit was verified.

---

## 3. Locale axes — what varies, and the reviewer's rule

This skill does not encode any single market's norms. It encodes the *axes* along which
markets differ, so a reviewer knows what it must be told before scoring `REG-1` or `HON-5`.

| Axis | What varies | Reviewer's rule |
| --- | --- | --- |
| Greeting and formality | Default greeting, address form, how businesslike a first contact is. | Take the concrete forms from the locale skill or the project delta. Absent both, anchor on the posting's own register and record `locale_mode: "unknown"`. |
| Length expectation | Whether the norm is a dense five-sentence note or a one-page letter. | Score `LEN-1` against the **channel** band first; only apply a locale adjustment that was supplied to you. |
| Self-promotion tolerance | How direct an explicit value pitch may be. | Unevidenced hype (`REG-3`) is `high` in every locale. Only the tolerance for *evidenced* directness moves. |
| Personal data | Whether a photo, age or marital status is customary on a CV, and whether volunteering it in a letter is unwelcome or an anti-discrimination hazard. | This is the hardest cross-locale backfire: never port one market's norm into another. Safe default in all locales — **never volunteer** age, marital status, photo, dependants, health or personal circumstances. Set `HON-5` severity from the target locale. |
| Money and terms | Whether compensation may be raised unprompted. | One rule both ways: salary, notice and relocation **only on request** (`HON-6`). Auto-insertion is the error everywhere. |
| Humor and creativity | How much individual voice a first contact tolerates. | `REG-4` — the posting's own tone is the licence; `industry_mode = creative` widens it. |
| Channel priority | Which channel is the default first contact. | Never port one market's default channel into another. Detect `channel` from the posting, not from habit. |

If the `ru-market-job-application-norms` skill is installed, apply it for Russian-language
letters — it supplies that market's register defaults, personal-data norms, instruction-gate
frequency and rewrite patterns. Otherwise these axes must be filled by the project delta.

---

## 4. Situation modifiers — `candidate_story` × `seniority` × `relationship_temperature`

| Situation | Opening should | Fit to sell | Explain explicitly | Tone and length | Especially harmful | Strength |
| --- | --- | --- | --- | --- | --- | --- |
| `no_direct_experience` / `junior` | role, motivation, nearest real proof — personal projects, coursework, internships, open source | learning potential, relevant fundamentals, stack, completed practical projects | readiness to start by a date or format; answer any literal instruction literally | short, energetic; no autobiography | pretending commercial experience exists; "passion" with no artifacts | **[strong]** |
| `mid` (standard) | anchor one or two relevant results to the requirements | repeatable delivery, stack, ownership in scope | usually nothing extra | 4–6 sentences / 80–140 words | generic words instead of specifics | **[common]** |
| `senior_ic` | lead with **scope** — systems, products, scale, impact — not years | architecture, complexity, cross-functional work, mentoring, business impact | brief domain fit and the problem types solved | calmer, less emotion, more quality signal | listing the whole career; writing like a junior ("eager to grow") | **[common]** |
| `step_up` | answer "why ready for the next level" immediately | expanded responsibility, leadership and ownership signals, results | yes: why this step is logical, not random | formally confident, not boastful | a bare "ready for a leadership role" with no scale signals | **[strong]** |
| `career_change` | name the change and the motive in the first lines | transferable skills, adjacent tasks, relevant courses and projects, deliberateness | yes, briefly: why change, why this direction | slightly more explanatory, still short | writing as if no change happened; or a burnout confession | **[strong]** |
| `gap_return` | the opening can stay normal; explain the gap in the body | what stayed current — study, projects, consulting, freelance, self-study | yes, if the gap is significant or would raise a question | calm, honest, no self-defence | inventing study that did not happen; extra personal detail | **[strong]** |
| `overqualified` | pre-empt the worry: why **this** role genuinely interests you | the relevant slice of experience, motivation, stable expectations, fit to the stated level | yes: why a narrower role, why you will not leave in a month | transparent, not defensive | hiding the mismatch; signalling boredom | **[strong]** |
| `internal` / `referred` | mention the internal or referral context up front, with permission; skip the self-intro if known | impact inside the organization, why this team, why now | current role, tenure, link to the new role | more direct and short | writing like an external stranger | **[common]** |
| relocation / timezone / remote | open normally, but place the constraint early **if the posting requires it** | fit plus practical feasibility | yes, when the posting asks about relocation, timezone or travel | dry, factual | hoping the reader will infer it | **[strong]** |

---

## 5. Industry modifiers — `industry_mode`

| Industry | How the logic changes | Best evidence | Tone | Length | Strength |
| --- | --- | --- | --- | --- | --- |
| `tech` | The letter is a **router to evidence**, not a novel: satisfy the instruction, then route fast to projects, stack and contribution. | code links, production and project examples, architecture or product results, experiments, performance work, ownership | concise, concrete, low salesiness | lower end of the band — a short note beats a long essay | **[strong]**; contested on whether a letter is needed at all |
| `creative` | More individual voice inside a professional frame; the letter itself demonstrates taste and writing quality. | portfolio, campaign cases, copy and design samples, audience research, process | warm-professional; moderate creativity welcome | medium; often a short letter plus portfolio | **[strong]** |
| `corporate_finance_ops` (incl. legal) | Higher price on tidy structure, written accuracy and evidence-based claims; less room for style play. | practical examples, measurable outcomes, process rigor, judgement | formal to warm-professional | medium or slightly above; a formal letter fits | **[strong]** |
| `mass_blue_collar` | The letter is often not the decision centre; availability, documents, schedule and basic skills matter more. | readiness to start, shifts, location, certifications, specific-operation experience | maximally factual | minimal | **[strong]** |
| `academic` | Not a five-sentence note but a specialized document: research, teaching, institutional fit, discipline norms. | research agenda, teaching interests, publication and disciplinary fit, institution-specific match | formal-academic | longer than a normal cover letter, still disciplined | **[strong]** |

---

## 6. Honesty boundary — the three buckets

The most useful classification a reviewer applies to **every** claim in the letter. A
fourth bucket, `unverifiable`, exists only for the degraded case (no CV) and is never a
quiet substitute for `evidence_backed`.

- **`evidence_backed`** — compresses or reorders a fact present in the CV, the posting or
  an explicit user fact. *Allowed.*
- **`safe_inference`** — a **mapping**: takes a posting requirement and links it to the
  nearest confirmed piece of the candidate's experience. *Allowed*, but it must not assert
  direct experience where only adjacent or transferable fit exists.
- **`forbidden_fabrication`** — invents a fact, number, team scope, ownership, tool or
  stack knowledge, domain, fluency, or a reason for a career transition. *Never.* →
  `critical`.
- **`unverifiable`** — the claim's backing could not be checked because an input was
  missing. Report it, name the missing input, and never let it roll up to a pass.

| Allowed | Forbidden | Safe rewrite |
| --- | --- | --- |
| Compress or reorder CV facts | Invent achievements, figures, team scope, ownership, stack, domain | No number in the source? Do not add one. Go qualitative: "worked on", "built", "supported". |
| Map a stated skill to a requirement | Claim direct experience where only transferable fit exists | "Direct experience with X" only if X is in the CV; otherwise "my work with A and B is adjacent to X and transfers quickly". |
| Derive motivation from the posting, product, project or stack | "I have always dreamed of working here" with no anchor | Name the concrete product, stack or problem taken from the posting. |
| Explain a gap, a career change or overqualification | Invent a reason for the break, the exit or the switch | No reason supplied? Do not invent one — shift to current skills and readiness to discuss. |
| Mention a referral or internal context | Invent a referral, or use a person's name without permission | Include the referral only if the user supplied it explicitly (`PD-2`). |
| State salary, notice or relocation | Assume compensation, start date, relocation or work authorization | Add only on an explicit fact or a direct employer request (`HON-6`). |

The four most dangerous fabrications, in order of how often they survive a careless review:
invented numbers, invented leadership scale, claimed knowledge of a specific named tool,
and invented reasons for a career transition. The first three are checkable against a CV in
seconds; the fourth is checkable only against what the user actually said, which is why
`truth_mode` exists.

---

## 7. Rule index

| ID | Name | Category | Default severity | Gate |
| --- | --- | --- | --- | --- |
| `INSTR-1` | `instruction_first` | instruction | `critical` | `instruction_mode != none` |
| `INSTR-2` | `instruction_exact_form` | instruction | `high` | `instruction_mode != none` |
| `INSTR-3` | `instruction_no_invention` | instruction | `critical` | `instruction_mode != none` |
| `TAIL-1` | `tailor_per_job` | tailoring | `high` | always |
| `TAIL-2` | `complement_not_repeat_cv` | tailoring | `medium` | always |
| `TAIL-3` | `mirror_requirements_naturally` | tailoring | `high` / `medium` | always |
| `PROOF-1` | `proof_over_traits` | evidence | `high` | always |
| `PROOF-2` | `numbers_traceable` | evidence | `critical` | always |
| `PROOF-3` | `route_to_artifacts` | evidence | `high` | `industry_mode = tech` |
| `PROOF-4` | `open_on_concrete` | evidence | `high` | letter / note / email |
| `LEN-1` | `channel_length_band` | length | `high` / `medium` | always |
| `LEN-2` | `scannable` | length | `medium` | always |
| `REG-1` | `locale_register` | register | `high` / `low` | `locale_mode != unknown` |
| `REG-2` | `monolingual` | register | `high` | always |
| `REG-3` | `no_overclaim` | register | `high` | always |
| `REG-4` | `humor_only_if_signalled` | register | `high` / `low` | always |
| `REG-5` | `no_editorializing` | register | `high` | always |
| `REG-6` | `no_gap_confession` | register | `high` | always |
| `CTA-1` | `specific_next_step` | cta | `medium` | `cta_strength != none` |
| `CTA-2` | `no_generic_close` | cta | `medium` | always |
| `HON-1` | `no_fabrication` | honesty | `critical` | always |
| `HON-2` | `claims_traceable` | honesty | `critical` / `high` | always |
| `HON-3` | `no_private_motivation` | honesty | `critical` | always |
| `HON-4` | `no_hidden_blocker` | honesty | `critical` | always |
| `HON-5` | `no_protected_characteristics` | honesty | `high` / `critical` | locale-dependent |
| `HON-6` | `terms_only_on_request` | honesty | `high` | always |
| `PD-1` | `no_autobiography` | honesty | `medium` | always |
| `PD-2` | `no_third_party_without_consent` | honesty | `high` | always |

Category names in this column are the `scores` keys: `instruction`, `tailoring`,
`evidence`, `length`, `register`, `cta`, `honesty`. `PD-*` rolls up under `honesty`.

---

## 8. Evidence base and maturity

Where the rules come from, and how much weight each carries. Sources are described by class
rather than named: platform documentation moves, and a rule that depends on one vendor's
current help page is a rule that will rot.

| Source class | What it supports | Strength |
| --- | --- | --- |
| Hiring-platform help centres and knowledge bases | length norms for short application notes, register defaults, the ban on clichés, the "tailor per application" rule | **[strong]** |
| Live postings in technical hiring | the instruction-response use of the message field: keywords, start dates, handles, code links | **[strong]** |
| University and public career centres | one-page formal letter, tailoring, omit protected characteristics | **[strong]** |
| ATS-vendor documentation | whether letters are keyword-scanned, and whether anything auto-rejects | **[contested]** — vendors disagree; mirror naturally, never stuff |
| Professional-network documentation | character limits for connection notes and outbound messages | **[contested]** — tiered by account type and revised periodically; treat published numbers as safe targets |
| Recruiter surveys, 2026 refresh | how letters are read, and the reception of AI-assisted applications | **[common]** — self-reported survey data, directionally consistent across publishers |

Data points behind the weighting, from the 2026 refresh — treat as directional, verify
before quoting any figure to a user:

- Most hiring managers report reading cover letters most of the time, and a majority say a
  strong letter can win an interview on an imperfect CV.
- Obviously AI-generated content is received negatively by a large majority of managers,
  while AI-*assisted* letters customized with real achievements are received favourably by
  a clear majority. A significant minority say they would reject an application they
  believed was AI-generated.
- The operative asymmetry: penalize generic fluff, reward verifiable specificity and a
  voice that survives the edit. The engine principle is **not prettier, more accurate** —
  which is why `HON-*` and `PROOF-*` outrank every style rule in this file.

**Maturity:** the rubric has been applied to generated-letter corpora and to hand-written
letters; the `INSTR-*`, `HON-*` and `REG-5`/`REG-6` families are the ones that repeatedly
change a verdict. The situation and industry modifiers (§4, §5) are the least exercised
part of the taxonomy — they are authored from source guidance, not from measured review
data. Say so when a finding rests only on them.
