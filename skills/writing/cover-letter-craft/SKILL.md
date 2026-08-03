---
name: cover-letter-craft
description: The craft model for a job-application letter — what the reader is actually deciding, the strategy done before any prose (diagnose the fit, choose one controlling idea, select two or three proofs, bridge gaps instead of confessing them), the rules for opening, evidence, length and close, honesty treated as the persuasive move rather than a constraint, the personalisation depth ladder, the intake that sets the quality ceiling, and how to tell whether any of it works. Use when asked to "write a cover letter", "help with my application letter", "improve/rewrite this cover letter", "why is my letter getting no replies", "what do I say about my career gap", "how long should a cover letter be", "make this sound less generic / less AI", "coach me through this application", or when building or reviewing a system that drafts application letters.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Cover-letter craft

The judgment a good career coach carries in their head, made explicit: what the letter is
for, what the reader is doing while they read it, and the decisions taken *before* a word
is written.

**This skill defines only** the craft and coaching model for a job-application letter —
purpose, reader model, pre-writing strategy, sentence-level craft, the honesty discipline,
the personalisation ladder, intake, and measurement. It does **not** define a CV/résumé
format, interview preparation, salary negotiation, any single market's etiquette, or the
architecture of a product that generates letters. Locale norms (greeting register,
personal-data conventions, whether the letter field is used as a compliance test) are a
*market* question: if the `ru-market-job-application-norms` skill is installed, read it for
the Russian-language market; otherwise treat section 8's locale rule as the only universal.

**Maturity.** This is doctrine synthesised from published recruiter research and coaching
practice, not from incidents in this library's own systems — so it carries **no `[!]`
markers**. Percentages come from 2024–2026 recruiter surveys and statistics roundups; they
corroborate each other and are directionally reliable, but treat them as order of magnitude
rather than measurements of your market.

---

## 1. What a cover letter actually is

Almost everyone writes the wrong document. Correct the mental model first, or every later
rule is applied to the wrong artifact.

**A cover letter is a risk-reduction and relevance argument — not self-expression.** Hiring
is an investment decision under incomplete information: the employer cannot see competence
directly, so they read *signals* and try to lower the probability of a bad hire. Every
sentence either lowers their perceived risk or raises it. "Passion", "my story" and
"showing personality" are worth something only insofar as they reduce risk or sharpen
relevance; otherwise they are noise the reader pays for in attention.

The letter is also not the product. The *interview* is the product. The letter is one move
in a system (CV + letter + profile + channel + timing) whose only real metric is
reply/interview rate.

### 1.1 The reader is answering exactly two questions

1. **Can this person do the job?** (capability / proof)
2. **Will this person be low-friction and a fit?** (risk / motivation / how easy to work with)

A strong letter answers both fast and leaves a third impression — *this was written for
us* — which is itself a risk signal: someone who bothered to understand the role is less
likely to be a mis-hire.

### 1.2 The one-line test

Every strong letter compresses to **"why you, why this role, why now."** If you cannot
extract all three from your own draft, the draft is unfinished. A letter that cannot be
summarised in three sentences is doing too much.

### 1.3 Complement, not duplicate

The CV is the evidence file; the letter is the *argument over the evidence*. Re-narrating
the CV wastes the one channel where interpretation, context and connection are possible —
the things a bullet list cannot do.

### 1.4 When the letter has leverage

Calibrate effort to leverage. The best writer is not the one who writes the longest letter
every time; it is the one who writes **exactly the message the situation rewards** —
sometimes five lines, sometimes one paragraph answering one question, occasionally nothing
but the artifact link the posting asked for.

| Leverage | Situation | What to do |
|---|---|---|
| **Highest** | The match needs a bridge: career switch, title mismatch, employment gap, overqualified | Write the full argument; the bridge *is* the letter |
| **High** | The role weights written communication; the channel is direct (email or DM to a named human); the posting requires a letter | Write, short and specific |
| **Medium** | Standard portal application with a strong on-paper match | A tight half-page; do not pad |
| **Low** | High-volume mass screening; a knockout question or portfolio link is the real gate | Satisfy the gate exactly; keep prose minimal |
| **None** | The posting asks only for an artifact | Send the artifact |

Decide **whether this should be a letter, and how long**, *before* drafting. That decision
is upstream of every craft rule below.

---

## 2. The reader's mind

You are not writing for "an employer". You are writing for a specific, tired, skimming
human (sometimes a machine first), under time pressure, defaulting to *no*.

### 2.1 The reading pipeline has up to three gates

| Gate | What it does | Appetite | What it means for you |
|---|---|---|---|
| Parser / applicant-tracking system (sometimes) | May store and keyword-search the letter | Mechanical | **Contested**: some vendors say letters are keyword-parsed, others say no automatic reject and humans decide. Safe conclusion: mirror the posting's real vocabulary **naturally**; never keyword-stuff, never paste the job description, never hide text |
| Recruiter — the skim | Filters, does not savour | ~**66% spend under 30 seconds**; the rest 30s–2min | Pattern-matching for relevance, disqualifiers and red flags. They read selectively but remember clarity |
| Hiring manager — the read | Actually reads, if you survived the skim | Minutes | **49%** say a strong letter can win an interview for an otherwise-weak candidate; **83%** say a strong letter can secure an interview when the résumé alone would not. This is where the argument pays off |

### 2.2 The six-second decision

A hiring manager spends roughly **six seconds deciding whether the letter is worth reading
at all**, and the **opening line** is what converts those six seconds into sixty. The first
sentence is not a warm-up; it is the whole letter's audition.

### 2.3 The four biases you are writing into

| Bias | The mechanism | The number | Your counter-move |
|---|---|---|---|
| **Default-to-reject / loss aversion** | With ~118 applications per opening and ~20% interviewed, the reader's cheapest action is *no*; they scan for reasons to eliminate | **>80%** of recruiters have rejected a candidate on the cover letter alone; **68%** dismiss for a single typo | Give **no cheap reason to reject** first (typo, generic opener, wrong length, unmet instruction), *then* a reason to advance |
| **Pattern-matching and the AI tell** | Readers run fast template-detection; "proven track record", "detail-oriented professional", "I am writing to express my interest" pattern-match to spam | Obviously-AI letters get **<30 seconds** vs **2–3 minutes** for authentic-sounding ones; **48%** auto-dismiss a non-customised letter | Generic is now **worse than no letter**. Specificity is the only reliable defence |
| **Halo / horn** | One vivid, specific, verifiable result casts a competence halo over everything else; one cliché or unsupported boast casts a horn | — | Specificity is the cheapest halo you can buy |
| **Fluency = competence** | Readers unconsciously read *easy to process* as *able* | — | White space, short sentences, one idea per line and clean formatting are a **competence signal**, not cosmetics |

### 2.4 What follows for the writer

- **Front-load relevance.** The strongest concrete proof goes in sentence one of the body.
  Never bury the lede behind biography or a windup ("My experience has allowed me to…").
- **Optimise for the skim.** Short sentences, one idea each, visible structure, ruthless
  length discipline. A wall of text or a buried lede is a real defect, not a style nit —
  readability is a risk signal.
- **Zero cheap-reject surface.** Before sending: no typo, every explicit instruction
  satisfied, length in band, no AI-tell phrase, no cliché.
- **Win the first sentence on purpose.** A deliberate bar for the opening line is worth
  more than any other single check you can apply.

---

## 3. Strategy before prose

This is where most letters — and most generators — are thin. A great coach spends more
time deciding *what to say* than saying it. The order is **diagnose → position → select →
bridge → only then draft.**

**Phase 1 — Diagnose the fit.** Lay the candidate's evidence against the role's *real*
needs: not just the stated bullets but the **job behind the job** (what problem is this
hire actually solving?). Produce three lists:

- **Strong and it matters** — direct, relevant, provable.
- **Adjacent** — transferable, needs a bridge.
- **Genuinely short** — a real gap.

This triage decides everything downstream. Do it explicitly; do not let it stay implicit in
the drafting.

**Phase 2 — Choose the angle (the throughline).** A world-class letter has **one
controlling idea** the whole letter serves: "I ship backends that survive load", "I'm the
person who turns messy discovery into a shipped roadmap". Choose the positioning that
maximises *relevant* contrast with the applicant pool. Without a throughline you get a
list; with one you get an argument.

**Phase 3 — Select, don't include.** Amateurs ask "what can I include?"; professionals ask
"what can I cut?" Choose the **two or three** proofs that most move *this* reader and
delete everything else, however true. Selection is where taste lives. **A letter that says
three things well beats one that says eight things adequately.**

**Phase 4 — Decide the gaps strategy: bridge, don't confess.** For each genuine shortfall,
classify it:

| Kind | Definition | Handling |
|---|---|---|
| **Soft gap** | Bridgeable with transferable evidence — an adjacent stack, a smaller scale, a neighbouring domain | **Bridge** with a near-equivalent strength. Never volunteer it as an apology ("while I lack…", "although I have no experience in…") |
| **Hard blocker** | A real knockout: work authorisation, a mandatory certification or licence, a non-negotiable location | **Surface it honestly** — to the *candidate*, and through the channel where it belongs. Never bury it as a sad clause inside the pitch, and never hide it |

Confession reads as risk; a confident bridge reads as competence. This is a strategy rule
before it is an honesty rule.

**Phase 5 — Position the situation.** Junior, switcher, returner, overqualified, stepping
up — each carries a *predictable objection*. Answer it pre-emptively, before it forms in
the reader's mind. The overqualified candidate's entire opening job is answering "why won't
you leave in a month?"; the switcher's is "why this, why now, and why is it not a whim?"

**Phase 6 — Find the one company or role insight.** The single most undervalued and
hardest-to-fake move: **one precise, genuine reason tied to *this* employer** — a product
they shipped, a problem visible in the posting, a technical choice, a market they are in.
This is the difference between "I admire your innovative culture" (worthless, universal)
and "your move to event-sourced billing is exactly the problem I spent two years on". It is
the strongest fit-and-low-risk signal available, because only a real, attentive candidate
can produce it. It requires *research*, not phrasing — and it has an honest fallback:
if you have nothing true and specific, say nothing rather than manufacture admiration.

---

## 4. The craft

Strategy chooses the argument; craft makes it land in seconds.

1. **The throughline, executed.** One idea, stated or implied in the opening, paid off by
   every paragraph, closed at the end. After one pass the reader should be able to say what
   you are "about".

2. **The opening earns the second sentence.** Kill the windup — **99% of candidates open
   with "I am writing to apply for…"**, which says nothing the reader does not already know.
   Open the *body* on the **hardest concrete result you own**: a number, an outcome, a named
   artifact ("Cut CI build time from 18 minutes to 6 on a 40-service monorepo"). The test:
   **read it aloud — if the sentence could appear in someone else's letter, it is not yours
   yet.** A brief channel-appropriate greeting precedes the body; the *body's* first
   sentence is the hook.

3. **Show, don't tell — proof over traits.** "Communicative, stress-resistant, responsible"
   is invisible; readers discount self-described traits to zero. Replace each with evidence:
   a result, a number, a named project, a behaviour in a real situation. The sharp version
   of the rule: **never state what an achievement demonstrates** ("…which shows my ability
   to…"). State the achievement and let it demonstrate itself. Editorialising is the tell of
   someone who does not trust their own evidence.

4. **Specificity is the whole game.** Numbers, named tools, named products, real scope.
   Specific is memorable, credible, and un-fakeable by a generic model. Vague is forgettable
   and reads as machine-written. Every sentence must fail the **"could anyone say this?"**
   test.

5. **Concision and momentum.** Best-performing letters land at **~150–250 words** — a tight
   half-page; **~70% of employers prefer half-page or shorter**. Every sentence has a job;
   cut anything that would survive unchanged in another applicant's letter. Length is not a
   virtue — **density of relevance** is.

6. **Voice and authenticity.** The market has inverted: with machines making generic free,
   **authentic specificity is the scarce good**. ~**80% of managers view obviously-AI
   content negatively, but ~63% favour AI-*assisted* letters customised with real
   achievements.** The winning pattern is hybrid: structure and fluency from the tool, but
   the candidate's **real results, real reasons and real register** carried through. It
   should sound like *a specific person who is good at this job*, not like "a strong
   candidate". Practically: plain words over inflated ones, sentence length varied like
   speech, one or two human concrete details no template would contain.

7. **The close: a small, specific, low-friction next step.** Not a demand ("please review my
   candidacy urgently"), not stock filler the eye slides off ("I look forward to the
   opportunity to discuss"), but a conversation-starter the reader can act on cheaply:
   "Happy to send the repository for the scheduling service — is a 20-minute call next week
   workable?" Write from **confident parity**, not supplication: you are proposing a
   mutually useful next step, not begging for consideration.

8. **Mechanical perfection is non-negotiable.** **68% reject for a single typo.** A flawless
   surface is not polish; it is the price of being read. Proofread against the letter's own
   output language, not yours.

If the `purposeful-text-writing` skill is installed, its rules on cutting filler and
earning every sentence apply here unchanged; this section is the job-application-specific
layer on top of it.

---

## 5. Honesty as the competitive move

Most advice treats honesty as a guardrail bolted on at the end. Treat it as **strategy**:
truth is not the constraint on persuasion — it is the most persuasive and lowest-risk thing
you have.

**Why truth wins, concretely:**

- **It survives the interview.** The letter's job is to earn a conversation that then
  re-tests every claim. Fabrication does not fail at the letter; it fails later and worse.
  The only claims worth making are the ones you can defend in the room.
- **Specific truth out-competes generic puff.** The honest move and the winning move are
  usually the *same* move: a real number beats "significant impact"; a real reason beats
  "I have always admired you". Honesty forces specificity, and specificity is what wins.
- **Calibrated confidence reads as competence.** Overclaim ("I am the perfect candidate",
  "I exceed all requirements") signals insecurity and risk. Stating real results plainly and
  naming a real gap without flinching signals the opposite.

### 5.1 The three buckets — classify every claim

| Bucket | Definition | Verdict |
|---|---|---|
| **Evidence-backed** | Compress or reorder a fact already present in the CV, the posting, or something the candidate explicitly stated | **Allowed** |
| **Safe inference** | A *mapping*: connect a role requirement to the nearest **confirmed** piece of the candidate's experience — "my work on A and B is adjacent to X and lets me ramp fast" | **Allowed, and this is where honest letters are made.** It is *not* a licence to claim direct experience with X when only adjacency exists |
| **Fabrication** | Invent a number, a tool, a title, a team size, a language fluency, a domain, or a *reason* for a career move | **Never.** The most tempting and most dangerous are invented **metrics**, invented **leadership scale**, and invented **stack knowledge** |

The quality difference between a timid honest letter and a *winning* honest letter is
almost entirely the quality of the safe inferences — the requirement→evidence mapping. Put
effort there, not into loosening the fabrication line.

### 5.2 Honest framing patterns

What to do *instead* of lying:

| Situation | Dishonest reflex | Honest move |
|---|---|---|
| No number for a real achievement | Invent a plausible percentage | Go qualitative: what you built, owned, shipped, or participated in |
| Only adjacent experience | Claim the requirement outright | Bridge: name the adjacency and the ramp it enables |
| No stated motivation | Invent a personal myth about the company | Derive it from the product, stack, problem or role in the posting |
| An employment gap with no reason given | Invent a story | Shift to current skills and readiness to discuss it |
| A hard blocker | Hide it and hope | Surface it to the candidate; handle it through the channel, not as a buried apology |

### 5.3 The line you hold

The candidate may *ask* for a lie ("say I'm fluent", "add two years"). The honest
alternative is the offer. Refuse the fabrication **calmly, explain why — it surfaces at
interview — and produce the strongest honest version instead.** Never be accusatory; the
candidate is usually anxious, not dishonest. Hard blockers and risky claims are always
surfaced; no preference setting suppresses them.

If the `writing-honesty-gates` skill is installed, it defines how to enforce this in a
generative system (claim audit, blocking gates, evidence ledger); this section defines the
*stance*, which applies whether a human or a tool is writing.

---

## 6. The personalisation depth ladder

"Personalise it" is the most repeated and least useful advice. Personalisation has levels;
most of it is theatre, and only the top rungs move response rates. Climb as high as the
facts honestly allow — and know which rung you are on.

| Rung | What it looks like | Signal value | Notes |
|---|---|---|---|
| **0 — None** | A template; role and employer not named | **Negative** — worse than no letter; ~48% auto-dismiss | The failure mode to never ship |
| **1 — Surface** | Correct employer name and the exact role title as written in the posting | Low, but **mandatory hygiene** | Recruiters use it as the "wrote-for-us vs mass-mail" tell |
| **2 — Requirement mirror** | Naturally reflects 3–5 real requirements in the candidate's own words | Medium | Helps the skim *and* any keyword parse — without stuffing |
| **3 — Role-problem fit** | Connects a specific proof to the *specific problem* this role solves | High | The "job behind the job". Most letters never reach here |
| **4 — Employer insight** | One precise, genuine reference to their product, technical choice, market, or a detail in the posting | **Highest, hardest to fake** | The top-1% move (§3, phase 6) |
| **5 — Person / timing** | A true, relevant trigger: a referral, shared context, why *now* | Highest when genuine | Powerful in warm, referred and direct-message channels; **never fabricate the connection** |

**The rule: climb to the highest rung the facts support, and stop.** A fabricated rung 4
("I have always admired your culture") is *worse* than an honest rung 2, because it
pattern-matches to puff and adds risk. Rungs 3–5 move replies; rungs 0–1 are table stakes;
fake enthusiasm at any rung is theatre the reader discounts or penalises. "Personalisation"
that is only adjectives about the employer — innovative, fast-growing, industry-leading —
is rung 0 wearing a rung 4 costume.

Rung 4 requires *data* (research on the employer), not better phrasing. Rung 5 requires the
candidate, and can only ever come from them.

---

## 7. Intake: the ceiling is set before you write

The quality ceiling is fixed **before any drafting**, by what you know about the candidate.
A master coach's weapon is not prose; it is the conversation they have with the client
first. A CV cannot contain the three things a winning letter most needs.

**What a CV does not contain:**

1. **Genuine motivation — the real "why this, why now".** Not "I am passionate about your
   mission", but the true reason: the problem they want to work on, the product they
   actually use, the move this makes in their career. This is the scarce input behind rung
   4–5 personalisation *and* the honest version of enthusiasm. Raw motivation is often
   private and unflattering ("I need to leave my manager"); use its *meaning*, ship only the
   strategic translation, and never leak the confession into the letter.
2. **The proudest, most specific result** — the one number or shipped thing they would
   defend in an interview, which a terse CV bullet usually flattens.
3. **Constraints and context the reader will ask about** — start date, location and
   relocation, work format, notice period, the reason behind a gap or a switch. These are
   exactly the *risk* questions; answering the relevant ones pre-empts the objection.

**Ask few, sharp, decision-relevant questions — and never interrogate.** A great coach does
not hand over a 30-field form; they ask the two questions that change the letter. In
practice:

- Surface only the **few most decision-relevant** clarifications, most important first.
- **Cap the count** and ask one at a time.
- **Never guess a value only the candidate can know** — language level, years of
  experience, salary expectation, availability. Ask, or leave it out.

**Extraction is the floor.** If drafting happens from an extracted set of facts rather than
the raw CV, the extraction step is the **specificity ceiling for the whole letter**: a
lossy extraction drops a number no downstream rewriting can recover. Whoever or whatever
does that extraction deserves the best available effort, and is the wrong place to economise.

**Memory compounds.** Durable confirmed facts — skills, certifications, results — carried
across applications make each successive intake shorter and better. Scope what you recall to
the current posting, so recall helps rather than clutters.

---

## 8. Coaching mode

When you are coaching a person rather than producing an artifact:

- **Diagnose out loud, briefly.** Tell them which rung they can reach and why; tell them
  which gaps are soft and which are hard. The triage is the value; the prose is downstream.
- **Coach in the candidate's language; write the letter in the employer's language.** An
  English-language posting must not cause you to interrogate a non-English-speaking
  candidate in English. Conversation locale and artifact locale are separate decisions, and
  the letter itself is **monolingual** — never a mix.
- **One reframe, not a lecture.** If the candidate's stated motivation is unusable as
  written, reframe it once, gently, and move on. Do not moralise.
- **Give the objection, then the answer.** "A reader will ask why you left after eight
  months — here is the version that answers it in one clause."
- **Refuse fabrication without accusation** (§5.3), and always offer the strongest honest
  alternative in the same breath.
- **Know when to advise writing almost nothing.** If the situation has no leverage (§1.4),
  say so. A coach who always produces a full letter is not coaching.

---

## 9. Measurement

A coach's reputation lives on outcomes, not on how nicely the letters read. Three tiers, in
order of truth:

| Tier | What it measures | Strength | Weakness |
|---|---|---|---|
| **1 — Outcome** | Reply and interview-invite rate | The only thing that ultimately matters. Base rates to beat: tailored letters correlate with ~**1.9× interview likelihood** and a **35.8% vs 21.2%** hiring rate (always-tailored vs never); ~118 applicants per role, ~20% interviewed | Slow and confounded by CV, role and market |
| **2 — Blind preference** | Same CV and posting, your letter vs a strong generic one-shot baseline, judged blind, several judges to damp variance, reported as win rate ± spread | Isolates the contribution of the method; runnable on every change | Cannot catch a rare fabrication |
| **3 — Rubric and hard gates** | Rule-level pass/fail: fabrication, dropped hard blocker, banned phrase, wrong locale, leaked private data | Catches catastrophes; tells you *which* property a cohort fails | Cannot tell you the letter is persuasive |

**Both upper layers are needed.** Gates stop disasters but do not measure persuasion; blind
preference measures persuasion but misses the rare fabrication. The bar is **win the blind
comparison *and* never trip a hard gate** — neither alone is sufficient. Hard gates are
pass/fail, never averaged: one fabrication reds the run.

Keep the test set hard — switchers, title mismatches, hard blockers, adversarial requests
to lie, motivation-bearing cases, non-native-language output. A method is only as good as
its worst important case, and easy cases hide everything.

---

## 10. If you are building a generator

The same model, expressed as capabilities. Each row is a coaching principle, what it
demands of a system, and how you would know it works.

| Principle | Capability it demands | How to measure |
|---|---|---|
| Letter = risk reduction + relevance | Frame set in the system's own preamble; explicit "why you / why this / why now" check before finalising | Blind preference; "summarisable in three sentences" |
| Design for the skimming, default-no reader | Open on the hardest concrete proof; readability and length gates | Opening-line bar; length in band |
| Diagnose before writing | A distinct step producing strong / adjacent / short, separate from drafting | Proof-point specificity; gap precision |
| One controlling idea | A named throughline emitted before drafting and bound by every sentence | "One idea" check; ≤3 proofs |
| Selection over generation | Rank *and cap* proof points — the drafter sees only the best two or three | Cap enforced; specificity score |
| Bridge gaps, surface blockers | Soft→bridge, hard→surface to the user; in-letter confession banned | Hard-blocker-surfaced gate; zero confessions |
| Show, don't tell | Editorialising ban; trait-without-evidence rejected | Claim audit |
| Honesty as strategy | Claim-level audit (evidence / safe inference / fabrication) against sourced facts, enforced in depth — prompt, reviewer, and a deterministic gate — so a weak claim cannot be upgraded by asserting it | **Zero-fabrication hard fail**; fabrication rate as a headline safety metric |
| Personalise to the true rung | Employer research as an input, plus rung awareness and an honest fallback | Rung distribution; insight presence |
| Authentic voice | Real register captured at intake; cliché and AI-tell phrase list, widened as the market's tells drift | AI-tell phrase rate; human spot-check |
| Right channel and shape | Channel decided upstream of drafting, with real length and structure bands; explicit posting instructions satisfied *first*, in the exact form requested | Instruction-satisfied rate; length by channel |
| Win the next step | Specific, low-friction call to action; generic-close gate | Generic-close rate |
| Get the inputs first | Few capped clarifications, never guessing a candidate-only value; durable fact memory | Clarification relevance; value-never-guessed |
| Prove it beats the baseline | Blind preference plus hard gates run before every change | Win rate ± spread; no regression |

**The frontier — where this is actually won.** The rules are largely solved; the last 20%
is not:

1. **Genuine employer insight at scale** — rung 4 is the least fakeable, highest-value move
   and cannot be produced without real research data. The moat is the research, not the
   phrasing.
2. **Authentic voice without a fingerprint** — sounding like *this specific person* rather
   than "confident generic", consistently.
3. **Calibrated confidence** — neither supplication nor overclaim, held steadily across
   seniorities and stories.
4. **Knowing when not to write** — the discipline to ship five lines, or just the artifact
   the posting asked for.
5. **Selection over generation** — teaching the system what to *leave out* beats any
   improvement in sentence-level fluency.

---

## Definition of done

A letter is ready when all of these are true:

- [ ] The situation was checked for leverage, and the chosen length and channel match it.
- [ ] "Why you / why this role / why now" are all answerable from the draft.
- [ ] One controlling idea; every paragraph serves it.
- [ ] The body's first sentence is a concrete, specific result that could not appear in
      anyone else's letter.
- [ ] Two or three proofs, ranked and capped — nothing included merely because it is true.
- [ ] No self-described traits without evidence; no sentence explaining what an achievement
      demonstrates.
- [ ] Every claim is evidence-backed or a safe inference; zero fabrications.
- [ ] Soft gaps bridged, not confessed; hard blockers surfaced to the candidate.
- [ ] Personalisation is at the highest rung the facts support, and no higher.
- [ ] Employer and role named exactly as the posting writes them.
- [ ] Every explicit instruction in the posting is satisfied, in the exact form requested.
- [ ] Length in band for the channel (~150–250 words for a standard letter).
- [ ] No cliché, no AI-tell phrase, no windup opener, no stock close.
- [ ] The close proposes one small, specific, low-friction next step.
- [ ] Single language throughout; flawless spelling and grammar in that language.

If the `review-cover-letter` skill is installed, run it as the independent check — it
encodes this list as a graded rubric with severities, which is a stricter and more useful
verdict than self-review.

---

## Project delta

A consuming project supplies:

- **Output locale(s) and register presets** — greeting conventions, formality, and
  personal-data norms per target market. This skill is deliberately locale-neutral; a
  market pack or project skill supplies the norms.
- **Channel length and shape bands** — what "a direct message", "an email", "a portal note"
  mean here in lines and words.
- **The banned-phrase and cliché list**, in each output language, plus who maintains it.
- **The research source for employer insight** (rung 4) — where the facts come from and
  what counts as verified.
- **The candidate-fact store**, if any: what is remembered across applications, and the
  boundary between private truth (raw motivation, personal circumstances) and shippable
  content.
- **The evaluation harness** — the baseline for blind comparison, the judge configuration,
  and which gates block release.
