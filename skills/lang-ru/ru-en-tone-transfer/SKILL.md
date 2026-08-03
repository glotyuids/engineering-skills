---
name: ru-en-tone-transfer
description: How to move product copy between Russian and English when a literal translation would be wrong — declare one source language and treat the other as an adaptation, handle the irony asymmetry (a register that reads gently dry in Russian reads noticeably colder in English), the loanword register trap (an ordinary English word often reads as jargon once borrowed into Russian), names and idioms that do not survive translation, and the reverse direction where English-source products inherit Russian formality defaults and pushy-marketing register. Use when the user says "translate this copy into Russian", "localise the landing page", "the English version sounds off", "why does this read so cold in English", "adapt these UI strings for the Russian market", "make the English version match", "review this RU/EN string pair", or whenever a change ships the same message in both languages.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# RU/EN tone transfer — the other language is an adaptation, not a translation

**Core rule: English copy is not a translation of Russian copy, and Russian copy is not a
translation of English copy. Declare one source language, then write the other so it reads
as if it had been written there first. The deliverable in each language is copy that reads
native — not a sentence that matches the other sentence.**

This skill defines only what changes when the *same message* has to exist in Russian and
English: which language leads, how much irony survives the crossing, how borrowed words
change register, what to do with names and idioms that do not travel, and how to review a
finished pair. It does not define your product's voice, vocabulary or banned words — those
are project-layer decisions. It does not cover Russian grammar mechanics (plural forms,
gendered past tense, «ты»/«вы» propagation) — the `ru-ui-strings` skill in this pack owns
those. It does not cover catalogue layout, key naming or locale fallback — if the
`i18n-conventions` skill is installed, follow it for the mechanics; the
`bilingual-product-architecture` skill in this pack owns the question of *which* locale a
given artifact is produced in. If the `purposeful-text-writing` skill is installed, produce
the source string with it first; this skill runs on the crossing, not on the drafting.

**Maturity note:** this material comes from repeated bilingual copy reviews, not from
incident postmortems, so it carries no `[!]` markers. The numeric calibrations below are
rules of thumb that survived review, not measurements. Treat them as a starting dial, and
overwrite them in your project layer when a native reader disagrees.

## 1. Declare a source language

Before any string is written, the project records one answer:

| Decision | Why it must be explicit |
|---|---|
| **Which language is the source** | Adaptation is directional. Two "equal" languages means both get adapted from nothing and both read like translations. |
| **Whether the source can change per surface** | It can — marketing pages may lead in one language, error strings in the other. But it is recorded per surface, not decided per string by whoever is writing. |
| **Who signs off in each language** | A native reader per language, reviewing that language alone. |

Record the answer where the voice guide lives. The rest of this skill assumes it exists;
where it does not, say so before writing rather than inventing a direction silently.

## 2. The deliverable is a native pair, not a matched pair

Once a source is declared, the target language is written to the *job* of the source
string, not to its words. Practical consequences, all of which surprise people the first
time:

1. **String counts may differ.** One source sentence may become two target strings, or
   none. A clarification the source language needs may be redundant in the target, and an
   assumption the source can leave implicit may need saying.
2. **Sentence shape may differ.** Russian copy tends noun-heavy and impersonal
   («Данные сохранены»); good English is verb-first and short ("Saved."). Preserving the
   Russian construction produces "Data has been saved", which is nobody's English.
3. **The keys still have to match.** Divergent sentences, identical key sets. Sentence
   parity is not a goal; key parity is a build-time invariant — see the
   `bilingual-product-architecture` skill for how to enforce it.
4. **Review each language monolingually.** Ask "does this string do its job in this
   language, on this surface?" — not "is this an accurate translation of the other one?"
   Side-by-side review is how literal translations get approved.
5. **Never use round-trip machine translation as a quality check.** Back-translation
   rewards literal renderings and punishes exactly the adaptations this skill asks for. A
   pair that back-translates cleanly is usually the worse pair.

## 3. Irony and warmth do not cross at the same strength

The single most reliable asymmetry: **a dry, gently self-aware register that reads warm in
Russian reads noticeably colder — arch, or faintly sarcastic — in English.** English
readers hear the same observational distance as judgement.

So the English adaptation dials the same voice down. As a calibrated starting point, if the
Russian copy carries dry observational humour at roughly **4 out of 10**, the English
adaptation lands at roughly **2 out of 10** — about one dry observation per three blocks of
copy in Russian, roughly half that in English. This is a dial, not a law: it is the
direction and the ratio that matter, not the numbers.

What this means in practice:

- **Cut the dry line before cutting the information.** When the English version has to lose
  something, the observation goes first and the concrete detail stays.
- **What survives the crossing** is an observation about the *reader's situation* or a true
  contrast — something that would still be true if said plainly.
- **What does not survive** is wordplay, rhyme, cultural reference, register jokes, and any
  humour that depends on the shared frame of one language's readers.
- **What amplifies dangerously across the boundary** is sarcasm, ironic distance from the
  product, sassy microcopy, wink emoji, and self-deprecating jokes about the product or
  about the machine that generated the text. A line that is merely cheeky in the source
  reads as either hostile or unserious in the target. If your voice guide allows these at
  all, they stop at the language boundary.
- **The reverse direction has a matching trap.** Flat, neutral English translated literally
  into Russian often lands as bureaucratic rather than calm, because Russian reaches that
  register with different constructions. Equal warmth requires unequal devices.

## 4. The loanword register asymmetry

This is the subtlest rule in the skill and the one most often missed.

**An ordinary English word frequently becomes professional jargon the moment it is borrowed
into Russian.** The English source term is what an ordinary reader says; its transliterated
Russian form is what the product team says in meetings. So the two versions of the same
string legitimately differ in kind: **the Russian version describes the mechanic plainly,
while the English version can simply use the native term.**

Invented, neutral illustrations (a booking product):

| Concept | English copy | Russian copy | Why they differ |
|---|---|---|---|
| Reserving a time | "Pick a slot." | «Выберите время.» | «Слот» is scheduler jargon; the plain word is what the reader would say. |
| A queue for a full session | "Join the waitlist." | «Записаться в очередь.» | The borrowed form belongs to product decks, not to the reader. |
| First-run setup | "Finish onboarding." | «Закончить настройку.» | The borrowing is an HR/product term; the reader recognises the action, not the noun. |
| Summary screen | "Open the dashboard." | «Открыть сводку.» | The borrowing signals an analytics tool the reader did not ask for. |

The rule is **not** "avoid borrowings in Russian". Many borrowings *are* the ordinary
Russian word and replacing them with a native coinage reads stilted or bureaucratic —
«сайт», «файл», «браузер», «онлайн», «интерфейс». Some sit in the middle, where the choice
is a register decision your voice guide should settle once: «аккаунт» versus «учётная
запись».

The test, applied per term rather than per language:

1. Would a reader who does not build software use this word out loud? → Use it.
2. Do only practitioners use it? → In Russian, describe what the thing *does* instead. In
   English, the native term is usually fine on the same surface.
3. Does the target language have no ordinary word at all? → Describe the mechanic. Never
   introduce the borrowing to fill a gap the reader does not know exists.
4. Whichever you pick, pick once. One term per concept per language, recorded in the
   glossary — a term that alternates between borrowed and native forms across screens reads
   as two different products.

The asymmetry runs both ways in principle: a word that is ordinary in Russian may only have
an over-formal or clinical English equivalent. The test above is symmetric; the Russian
direction is simply where it fires most often.

## 5. Names and idioms that do not survive — anchor on what the thing does

A product name built on an idiom carries meaning to native readers and nothing at all to
everyone else. A literal rendering is worse than nothing: it produces a phrase that is
either meaningless or accidentally comic.

The pattern: **keep the name as identity, and let the copy around it anchor on the format —
what the thing actually is or does.**

- Do not translate the name. Do not gloss it in-line as a joke the reader is expected to
  get.
- In the target language, the sentence next to the name names the category in that
  language's own plain terms — the format, the activity, the artifact produced.
- Transliteration versus keeping the Latin spelling is a separate decision, and it is a
  Russian-side grammar problem: a Latin-script name does not decline. The usual fix is a
  Russian classifier noun in front of it, so the name stays undeclined — «в разделе
  <Product>», «режим <Feature>» — rather than forcing an inflected form.

The same procedure applies to idioms inside body copy: name the job the idiom was doing
(setting a playful register, naming a format, compressing an explanation), then achieve
that job with the target language's own devices, or drop it. If a string must keep an
effect that cannot be translated, mark it explicitly as "re-create the effect, do not
translate" and accept a different sentence per language.

## 6. The direction nobody plans for: English-source products moving into Russian

Teams building in English assume Russian is the "hard" language for grammar and the easy
one for tone. The opposite problems arrive instead.

**Formality is a decision English never forced you to make.** English "you" is neutral;
Russian makes you choose «ты» or «вы» in the very first string, and that choice then
propagates into every imperative, possessive and agreement in the catalogue. Decide once,
record it as a single configuration axis, and never let individual strings drift. Gendered
past-tense forms create the same class of problem: an English sentence with no gender
("You saved 3 photos") has no neutral Russian past-tense equivalent, so the Russian string
is rephrased rather than translated. The `ru-ui-strings` skill in this pack covers both
mechanics.

**Marketing register calques badly and reads as hard sell.** English product-marketing
enthusiasm, rendered word-for-word, lands in Russian somewhere between a brochure and spam
— and the reader discounts the whole surface, not just the sentence.

| English source | Literal Russian rendering | What it reads as | Adapt to |
|---|---|---|---|
| "Discover / Explore" | «Откройте для себя» | Brochure calque | Name the destination: «Каталог», «Посмотреть» |
| "Unlock your potential" | «Раскройте свой потенциал» | Infomercial | Name what the reader can now do |
| "Get started today!" | «Начните прямо сейчас!» | Pressure | Verb plus object: «Создать <object>» |
| "Just launch it" | «Просто запустите» | Dismissing the reader's difficulty | Say what the step actually is |
| "We're excited to announce" | «Мы рады сообщить» | Corporate voice in a UI | State the event |
| "Awesome! Saved successfully!" | «Отлично! Успешно сохранено!» | Shouting on a routine action | «Сохранено.» |

Further rules for this direction:

- **Exclamation marks are stronger in Russian.** One on a routine confirmation reads as
  shouting or as an obviously automated voice. Default to none in UI strings.
- **Superlatives and categorical claims cost more.** "The best", "the only", "the simplest"
  translate into claims a Russian reader discounts faster than an English one, taking the
  surrounding copy's credibility with them.
- **Politeness words are not one-to-one.** English "please" in an instruction is filler;
  «пожалуйста» in a Russian imperative either disappears or turns the instruction into a
  plea. English "sorry" padding maps onto Russian apologies that sound heavier than
  intended.
- **Title Case does not exist in Russian.** Copying English capitalisation into Russian
  headings looks like a rendering bug. Sentence case, always.
- **Leave room.** Russian commonly runs 10–30% longer than terse English; a control that
  fits its English label exactly is a layout bug in waiting. If the `i18n-conventions`
  skill is installed, follow it for how the layer handles length and overflow.
- **The stiffness trap in the other direction.** Over-formal Russian source
  («Осуществить вход») translated literally produces bureaucratic English ("Perform
  login") where the natural string is "Log in". Diminutives and softening particles simply
  vanish; do not try to compensate for them with English adjectives.

## 7. Reviewing an adapted string pair

Run this on the pair, having first read each string in its own language alone.

- [ ] The source language for this surface is known, and the other string was written as an
      adaptation of the job — not of the words.
- [ ] Each string reads as if written natively. Neither carries the other's sentence shape.
- [ ] Humour level is calibrated per language, with the English side dialled down; no
      sarcasm, ironic distance or sassy microcopy survived the crossing in either direction.
- [ ] No term in the Russian string is a borrowing that only practitioners use; where the
      English side uses a native term, the Russian side describes the mechanic.
- [ ] One term per concept per language, matching the glossary.
- [ ] Names are unchanged and un-glossed; the surrounding copy anchors on the format.
      Latin-script names are not forced into inflected forms.
- [ ] Idioms and wordplay were either re-created natively or dropped — not translated.
- [ ] Formality («ты»/«вы») and gendered forms match the project's recorded decision.
- [ ] No exclamation marks, superlatives or pressure verbs entered the Russian string by
      calque.
- [ ] Keys are identical across catalogues even where sentences diverge; the longer string
      still fits its surface.
- [ ] Neither string invents a fact, a metric or a claim the other does not make. If the
      `writing-honesty-gates` skill is installed, apply it to both sides — an adaptation is
      a very easy place to acquire a claim nobody approved.

State explicitly what you did not do: strings you could not judge without seeing the
surface, pairs where the source language was ambiguous, and any place the voice guide and
the target language's norms conflicted. That conflict is a finding about the voice guide.

## Project delta

The consuming repo supplies:

- **The source language**, per surface if it varies, and the sign-off reader for each
  language.
- **The humour ceiling per language** — the dial this skill only gives a starting ratio
  for, and whether irony is allowed on the surface at all.
- **The bilingual glossary** — one term per concept per language, including the settled
  borrowed-versus-native choices and the do-not-translate list (names, feature names,
  legal terms).
- **The address form** («ты» or «вы») and any register exceptions.
- **Surface budgets** — the length the longer language actually has to fit.
- **Regulated text** — consent, billing, safety and legal strings that are translated under
  review rather than adapted freely.
