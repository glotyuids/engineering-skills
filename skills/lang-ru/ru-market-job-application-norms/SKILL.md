---
name: ru-market-job-application-norms
description: How job applications actually work in the Russian-language market and where habits from another market backfire — the default register and how it loosens by channel, the instruction-as-gate phenomenon where the application field is a compliance test before it is an essay, the real channel mix (job portals and their in-app chat, tech boards, messaging apps) versus applicant-tracking plus email plus professional network, personal-data and photo norms, money and terms, humour, and honest-bridge rewrite patterns. Use when writing or reviewing an application message for a Russian-language posting, when a user says «как написать сопроводительное письмо» or asks about «отклик на вакансию», when adapting a letter written for a US or UK application to the Russian market or the reverse, when a posting hides an instruction in the letter field, or when building a product that generates application messages for both markets.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Russian-market job-application norms

Written **in English about Russian**. The same application message is not internationally
portable, and the most expensive avoidable error is shipping one market's norms into
another's screening process.

**This skill defines only** market norms: register, channel shape, the instruction-as-gate
phenomenon, personal-data conventions, money and humour norms, and the cross-locale
backfires between the Russian-language and English-speaking markets. It does **not** define
what makes an application message good — the reader model, the strategy done before
drafting, the opening line, evidence selection, or the honesty stance. If the
`cover-letter-craft` skill is installed, that is the craft layer and this is the market
layer on top of it; otherwise apply this skill's norms to whatever craft rules the project
already uses. It also does not define a grading rubric with severities (if the
`review-cover-letter` skill is installed, that is where rule IDs and verdicts live), nor
CV/résumé formatting, interview preparation, or salary negotiation.

**Maturity.** These norms are synthesised from platform help material, live postings in both
markets, career-centre guidance, and practice building systems that generate such
messages — not from controlled experiments or from incidents in this library's own systems,
so this skill carries **no `[!]` markers**. Direction is reliable; treat exact numbers as your
market's starting hypothesis, not a measurement. Three confidence markers appear in the
tables:

- **[strong]** — stated concretely in platform documentation, live posting requirements, or
  major career centres.
- **[common]** — stable advice across credible sources, no controlled proof.
- **[contested]** — credible sources disagree, or a platform contradicts itself; the safer
  number is used and the disagreement is named.

Section 6 is nonetheless the most consequential rule here: it is the only failure whose
damage lands *after* the message is sent and cannot be revised away.

---

## 1. The default register

The Russian-market default, stated as a coach would set it: **short, to the point, formal
address, one or two concrete proofs, instruction compliance first.**

| Element | Default | Notes |
|---|---|---|
| Greeting | Neutral business greeting — «Здравствуйте» or «Добрый день» | Named addressee is a bonus, not a requirement; a missing name is not a defect here |
| Address form | The formal second person («вы») throughout | The informal «ты» reads as familiarity, not warmth |
| Style | Business register: plain, dense, no ornament | Officialese and bureaucratic padding are equally wrong — dense is not the same as formal-sounding |
| Slang, emoji, memes | Out by default | Loosens by channel (§2), never by enthusiasm |
| Biography | Out entirely | The message complements the CV; it never re-narrates a life |
| Employer and role naming | Exactly as the posting writes them | Recruiters use this explicitly as the wrote-for-us versus mass-mail tell |
| Copied text | Never | Recruiters in this market report spotting pasted, from-the-internet text instantly, and a template is treated as an «отписка» — a brush-off |

A blunt consequence of the density norm: a message here is often **four to six sentences**,
or five to seven theses. That is not a lazy short version of a full letter. It is the
expected shape.

---

## 2. Register shifts by channel

Formality is not a property of the market; it is a property of the channel. The single
most common in-market mistake is applying one channel's register everywhere — a portal-grade
formal letter dropped into a chat reads stiff and slightly robotic, and a chat-grade message
dropped into a formal letter field reads careless.

| Channel | Market | Length band | Register | Close | Anti-pattern | Strength |
|---|---|---|---|---|---|---|
| Formal letter (attached or required by the posting) | both | **180–320 words** (RU); **≤1 page** (US/UK-EU) | formal-professional | polite readiness to talk, with availability | CV retelling, biography, flowery prose | [strong] |
| Portal note (the «сопроводительное» field) | RU | **4–6 sentences** or **5–7 theses**; if the field states a micro-task, exactly what it asks — sometimes one phrase | concise business, dense | sometimes only «Буду рад обсудить детали»; in micro-task mode, none | a one-page essay; generic words; ignoring the instruction | [strong] |
| Screening questions plus a note | RU | mandatory answers first, then **2–4 sentences** | functional, plain | offer to go deeper in the interview or chat | covering an unanswered task with pretty prose | [strong] |
| Portal in-app chat follow-up | RU | **1–3 short replies**, then to the point | businesslike, more conversational | one short question or next step | a second long letter instead of a concrete follow-up | [strong] |
| Messaging-app direct message | RU | **250–600 characters / 3–6 short lines** | concise, plain, links to code or projects | binary next step: send two or three cases, or take a call | formal-letter style, wall of text, no context anchor, aggressive follow-up | [common] |
| Post-apply direct message | both | **40–90 words** | brief | tiny offer ("can send two cases") | re-sending the whole letter | [common] |
| Speculative approach (no open role) | both | **80–150 words** | restrained-direct | low-friction ask naming a direction or team | mass-mailing tone; no named role or direction | [common] |
| Cold email to a named human | both | **100–200 words**, ~130–140 preferred | businesslike | "is a short call workable?" | long letter, generic subject, pasted posting text | [common] |
| Warm or referred email | both | **60–120 words** | warm-professional | ask for the best route in | naming a referrer without their permission | [common] |
| Professional-network connection note | EN | **≤200 characters** safe (longer limits are paid-tier only — do not rely on them) | brief | minimal or none | a pitch inside a connection request | [contested] limit |
| Professional-network outbound message | EN | subject **≤200 characters**; body technically long but practically **60–130 words** | conversational-professional | one question, not "consider me urgently" | pasted posting text; a second follow-up before any reply | [strong] limit / [common] style |

**Rule of thumb across both markets:** the more direct and human the channel, the shorter
the message. Direct messages and connection notes should be shorter than instinct suggests.

---

## 3. Instruction-as-gate — the highest-leverage rule in this market

The sharpest local phenomenon. Postings on the Russian tech boards and portals routinely use
the application field as a **compliance and attention test**, not as a persuasion surface.
The field says things like «начните письмо со слова "омлет"», «укажите дату выхода и ник в
мессенджере», «пришлите ссылку на код», «укажите зарплатные ожидания».

When that happens, the message is not an essay at all. It is a gate. **Detecting and
obeying the instruction outranks every other quality of the message.** A beautifully argued
letter that ignores the keyword is rejected mechanically, and no eloquence offsets it.

Three rules, in order:

1. **Satisfy every explicit instruction before any persuasive copy.** Required keyword,
   start date, salary expectation, relocation answer, employment format, messenger handle,
   code or portfolio link — all of it goes first, above the pitch.
2. **Satisfy it in the exact form requested.** «Три–пять пунктов» answered as prose fails.
   «Одно предложение» answered with a paragraph fails. A requested artifact — a first-month
   plan, a link, a specific number — is not substitutable with an equivalent-in-spirit
   sentence.
3. **Never invent a fact to close a gate.** If an instruction needs something the candidate
   has not supplied — a level, a years count, a certificate, a salary figure — **surface the
   missing fact to the candidate and ask**; do not fill it plausibly. A fabricated gate
   answer is the worst possible outcome: it passes the filter and fails the interview.

**Gate types, and the cue that reveals each:**

| Gate | Cue in the posting | How it is satisfied |
|---|---|---|
| Keyword | "start your message with the word X", a stated code phrase | the exact token, in the exact position |
| Explicit question | a direct question inside the field text | a direct answer, before anything else |
| Availability | asks for a start date or notice period | a date or a period, not "as soon as possible" |
| Salary | asks for expectations, sometimes with a currency or a range format | a figure or range the candidate supplied — never one you inferred |
| Portfolio / code | asks for links, repositories, cases | the links themselves, not a promise to send them |
| Relocation / format | asks about moving, timezone, office or remote | a plain yes/no plus the constraint |

If none of these cues is present, the message reverts to a normal persuasion artifact. The
detection step is cheap and the miss is fatal, so run it every time.

---

## 4. Channel reality — two genuinely different markets

Neither market's channel mix is the default; they are different worlds, and porting either
as "the way applications work" degrades results.

| | Russian-language market | English-speaking market |
|---|---|---|
| Centre of gravity | General job portals and **their in-app chat**, tech-specific job boards, and **messaging apps** | Applicant-tracking systems reached through employer sites, **email**, and a professional network |
| Where the conversation continues | Portal chat, or a messaging app — postings frequently name a handle and expect contact there | Email thread, or the tracking system's own status flow |
| What the application field is | Often a gate (§3) or a dense note, sometimes an attached letter | Usually an attached or pasted letter, sometimes optional |
| What "short" means | 4–6 sentences in a portal note; 3–6 lines in a messaging app | ≤1 page for a formal letter; very short for network outreach |
| Failure mode of the outsider | Treating the portal note as a US-style one-page letter | Treating a messaging app as the appropriate first contact for a corporate role |

Two practical consequences:

- **The channel is data, not a preference.** If the posting names a messaging handle, that is
  the channel — writing a formal letter and emailing it instead is a miss, not a courtesy.
- **A messaging-app message is a different artifact**, not a shortened letter: context anchor,
  role, one proof, a link, one binary next step. Pasting a formal letter into a chat is the
  single most visible tell of someone applying by habit rather than by attention.

---

## 5. The locale matrix

The centrepiece. The third column is what almost nobody writes down: what happens when a
habit that is *correct* in one market is carried into the other.

| Axis | Russian-language market | US / UK-EU market | Cross-locale backfire | Strength |
|---|---|---|---|---|
| **Greeting and formality** | Neutral business greeting, formal «вы», business style — the default, and a missing addressee name is fine | The formal letter stays businesslike, but email and network outreach are more direct: named addressee, fast to the point | Russian bureaucratic formality rendered in English reads stiff and dated; English over-casualness in a first Russian response reads familiar and unprofessional | [common] |
| **Length** | Portal fields are short: 4–6 sentences / 5–7 theses; tech postings may demand one sentence, a keyword, a date, a link | The formal letter is still ≤1 page: motivation, fit, employer fit | A Western one-page essay pasted into a portal note ignores the format and reads as mass-mailed; a Russian five-liner where a full letter is expected under-delivers context | [strong] |
| **Self-promotion register** | "Selling theses" are fine, but hard against loud claims, self-comparison and empty traits — value must be *proven* | The letter is framed as a marketing artifact; an explicit value pitch is acceptable **when backed by examples** | The unbacked English pitch — "I am the ideal candidate", "I exceed all your requirements" — reads especially badly in Russian, where it signals insecurity rather than confidence | [strong] |
| **Personal data and photo** | A photo is tolerated on a Russian CV; marital status, biography, irrelevant hobbies and personal worries are unwanted everywhere | Career centres instruct candidates to omit photo, age and gender; disability, gender, marital status and dependants are not required and are not wanted | **The hardest backfire — see §6.** Russian-tolerated photo and personal-data habits carried into a US or UK application | [strong] |
| **Money and terms** | Do not raise salary or schedule unprompted — **but** postings here commonly *do* ask, and then it is an instruction to satisfy, not a faux pas to avoid | Salary requirements only when the posting explicitly asks | One rule in both directions: compensation, notice and relocation appear **only on request**. Auto-inserting them is the error; withholding them when the posting asked is the *other* error, and in this market that request is common | [strong] |
| **Humour and creativity** | Risky unless the posting's own tone signals it; more room in creative fields, and even there «не переборщить» | Avoid jokes, sarcasm and over-friendliness in a formal letter; convey enthusiasm through genuineness instead | Messaging-app irony ported into a formal email or portal note reads unprofessional in both markets — this is the one axis where the backfire is symmetrical and unforgiving | [common] |
| **Channel priority** | Job portals and their chat, tech boards, messaging apps; postings often name a handle | Tracking systems plus email plus a professional network, which rewards very short personalised outreach | Do not port a channel as "the default": a messaging-app first contact for US corporate outbound, or network-essay style dropped into a Russian chat, are both worse than the local norm | [common] |

**The two defaults, stated once:**

- Russian market → short, to the point, formal address, one or two concrete proofs,
  instruction compliance first.
- English formal letter → ≤1 page, named addressee where possible, fit plus an
  employer-specific reason, an evidenced value pitch.
- Any direct message, either market → shorter than you think.

---

## 6. Personal data — the hardest backfire

**Never carry Russian-market personal-data habits into a US or UK application.**

A photograph, a date of birth, marital status, dependants, or a line of personal
circumstance is tolerated — and sometimes expected — on a Russian-language CV, and a
candidate who has been applying locally for years will include them by reflex. In a US or
UK application the same fields are at best noise and at worst a screening problem:
employers there deliberately structure screening to *avoid* seeing protected
characteristics, and an application that volunteers them can be stripped, discarded, or
routed away from the person who would otherwise have read it. The candidate never learns
why. The damage lands after sending, and there is no revision that un-sends it.

Because the asymmetry is total — including this data helps nobody in either market, and
omitting it costs nothing in the Russian one — the safe default is the stricter norm in
**both** directions:

> **Never volunteer** age or date of birth, marital or family status, children or
> dependants, a photograph, health, religion, nationality, or personal circumstances —
> unless a legal requirement makes it both mandatory and relevant to the role.

Two adjacent rules that hold in both markets:

- **No autobiography inside the message.** Family situation, irrelevant hobbies, personal
  worries and life story do not belong in an application message even where a photo on the
  CV is unremarkable.
- **Private motivation stays private.** Burnout, a conflict with a manager, a financial
  emergency — these are real and often the true reason for applying, but the artifact ships
  only the strategic, sanitised translation of the motive, never the raw confession. If the
  `writing-honesty-gates` skill is installed, it defines how to enforce that boundary in a
  system; the norm itself holds regardless.

**Direction of travel matters for review, too.** When checking a message, first establish
which market it is *going to*, not which market the candidate is *from*. The habits travel
with the person, so the mismatch is invisible unless you look for it deliberately.

---

## 7. Money, terms and availability

One rule, two failure modes:

| Situation | Correct move | Failure |
|---|---|---|
| The posting says nothing about pay, notice or relocation | Say nothing | Auto-inserting a salary expectation, a start date, or a relocation statement the candidate never supplied |
| The posting asks for salary expectations, a start date, relocation readiness or work format | **Answer it, first, exactly as asked** (§3) | Treating the question as impolite and skipping it — a local-etiquette rule misapplied to an explicit instruction |
| The candidate has not given you the figure | Ask them | Inferring a plausible number from market data or the posting's own range |

The Russian-market nuance that trips outsiders: general advice in this market genuinely does
say "do not discuss money in the application" — and that advice is about *unprompted*
mentions. Postings on the tech boards ask for «зарплатные ожидания» often enough that
treating the ask as taboo is itself a common, silent rejection cause.

---

## 8. Humour, creativity and enthusiasm

- **Humour is licensed by the posting, not by the writer's mood.** If the posting's own text
  is playful, a light touch is safe. If it is neutral or corporate, it is not.
- **Creative fields have more room** — the message can show taste and writing quality — but
  the frame stays professional, and the local instinct is explicitly «не переборщить»: do not
  overdo it.
- **Enthusiasm is expressed through specificity, not adjectives.** «Всегда мечтал работать
  именно у вас» with nothing behind it is worse than saying nothing: it pattern-matches to
  mass-mail, in both markets. A precise, true reason — a product, a technical choice, a
  problem named in the posting — is the only enthusiasm that reads as real.

---

## 9. Honest-bridge rewrite patterns

Russian appears here as data. Each pattern is bad → good, invented as an illustration.

| Problem | Instead of | Write |
|---|---|---|
| Trait without evidence | «Я коммуникабельный и стрессоустойчивый» | «Вёл переписку с пятью командами в релизные недели и закрывал инциденты без эскалаций» — or delete it if nothing supports it |
| Windup opening | «Мой опыт в разработке позволяет мне быть полезным вашей компании» | Open on the hardest concrete result: «Сократил время сборки CI с 18 до 6 минут» |
| Overclaim | «Я идеальный кандидат и превосхожу все требования» | Delete. Let one concrete result carry it |
| Editorialising the evidence | «Запустил сервис, что демонстрирует мои сильные инженерные навыки» | «Запустил сервис, который обрабатывает пиковую нагрузку в отчётный период» — state the fact, never what it "demonstrates" |
| Confessing a soft gap | «Понимаю, что не работал в этой отрасли, однако…» | Bridge from strength: «Опыт вывода продуктов и работы с P&L переносится на задачи отрасли: …» |
| Claiming an unproven tool | «Имею богатый опыт с <инструмент>» when only the adjacent tool is in the CV | «Работал с <смежный инструмент> в проде; основы переносятся, готов быстро войти» |
| Manufactured motivation | «Всегда мечтал работать именно у вас» | «Меня заинтересовала роль из-за <конкретный продукт / стек / задача из вакансии>» |
| Stock close | «Надеюсь на возможность обсудить» | «Готов прислать два-три кейса или код — когда удобно созвониться?» |
| Missing gate answer | a polished pitch with no date and no handle | date and handle first, in the exact form asked, then the pitch |
| No number available | inventing a plausible percentage | go qualitative: «участвовал в…», «разрабатывал…», «поддерживал…» |

The rule under all of them: **not prettier — more accurate.** In this market, specificity is
both the honest move and the winning one; they are almost always the same move.

---

## 10. Conversation locale versus artifact locale

Two separate decisions, routinely collapsed into one and always wrong when they are:

- **The artifact follows the employer's language** — the language of the posting. An
  application to an English-language posting is written in English, end to end.
- **The conversation follows the candidate's language.** Coaching, clarifying questions and
  positioning notes are delivered in the language the candidate is speaking. An
  English-language posting must never cause you to interrogate a Russian-speaking candidate
  in English.

And one hard property of the artifact itself:

- **The message is monolingual.** A Russian greeting on an English letter, an English
  sign-off on a Russian one, or a sentence that mixes both, is a defect — not a
  bilingual flourish. Posting terminology is rendered naturally into the artifact's
  language rather than pasted across from the other one.

If the `ru-en-tone-transfer` skill is installed, use it for the register shift when the same
argument has to exist in both languages. If the `bilingual-product-architecture` skill is
installed, it covers how a product carries the two-locale split structurally.

---

## Definition of done

An application message for a Russian-language posting is ready when:

- [ ] The posting was scanned for an embedded instruction, and every one found is satisfied
      **first**, in the exact form requested (§3).
- [ ] No fact was invented to close a gate; anything missing was asked of the candidate.
- [ ] The channel was identified from the posting, and the length and shape match that
      channel's band (§2) — not the writer's habitual format.
- [ ] Neutral business greeting, formal «вы», business register, no slang or emoji unless the
      channel and the posting's own tone license them.
- [ ] Employer and role are named exactly as the posting writes them.
- [ ] Four to six sentences in a portal note; 3–6 short lines in a messaging app; a full
      letter only where a full letter was expected.
- [ ] One or two concrete proofs; no empty traits; nothing explaining what an achievement
      "demonstrates".
- [ ] No age, photo, marital status, dependants, health or personal circumstances — in either
      direction of travel (§6).
- [ ] Salary, notice and relocation appear only because the posting asked or the candidate
      supplied them.
- [ ] Monolingual throughout, in the posting's language; coaching delivered in the
      candidate's language.
- [ ] No copied-from-the-internet phrasing and no template that would survive unchanged in
      another application.

---

## Project delta

A consuming project supplies:

- **Target markets and direction of travel** — which locales it generates for, and whether a
  single candidate's material crosses between them (which is what makes §6 live rather than
  theoretical).
- **Channel set and length bands** — which of §2's channels this product actually targets,
  and the exact bands it enforces. The numbers here are defaults, not measurements.
- **Instruction detection** — where posting text comes from, whether the application field is
  parsed separately from the body, and what happens when a gate needs a fact the candidate
  has not supplied (ask, block, or hand back).
- **The banned-phrase and cliché list in Russian**, plus who maintains it as the market's
  tells drift.
- **The personal-data policy per destination market**, and whether it is enforced
  mechanically or by review.
- **The conversation-locale rule** — how the user's language is determined, and where that
  decision is stored, if the product coaches as well as generates.
