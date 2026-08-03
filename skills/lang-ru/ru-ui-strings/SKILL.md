---
name: ru-ui-strings
description: Writing and engineering Russian interface strings, in English. Covers the gendered past tense — any sentence about what the user did misgenders half of them unless phrased neutrally, a constraint that must also go into the prompt for model-generated text; the informal/formal address choice («ты» vs «вы») as one configuration point; the three integer plural categories with the mod-10/mod-100 rule and the 11–14 exception (a two-branch ternary is a bug); a binding glossary and enum-agreement traps; interpolated values landing in a fixed grammatical case; string expansion versus English; sentence case instead of Title Case; guillemets, em dashes and the optional letter «ё»; and a native review pass before launch. Use when the user says "add Russian", "translate the UI to Russian", "Russian copy", "RU strings", "why does the app call me he", "gendered forms", "«ты» or «вы»", "Russian plural forms", "the Russian reads machine-translated", or when writing any user-facing Russian string.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.1
---

# Russian UI strings

Russian is not English with different words in it. Three grammatical facts leak straight into
engineering: verbs and adjectives agree with the **gender of their subject**, counted nouns
take **three** integer forms, and every second-person sentence must pick one of **two address
forms**. Each of them turns a string that looks finished into a string that is wrong for some
users, at some counts, on some screens — and none of them fail a test or throw an exception.

## Scope

This skill defines only: **how a Russian user-facing string is worded and engineered** —
gendered forms, address form, plural categories, terminology, the interpolation hazards
specific to an inflecting language, typography, and the review gate before launch.

It does not define the i18n machinery — catalogue layout, key naming, parity enforcement,
fallback chains, the do-not-localize list. If the `i18n-conventions` skill is installed,
follow it for that layer; otherwise follow the project's own conventions. It does not define
register or tone transfer between languages (`ru-en-tone-transfer` in this pack), nor which
locales ship and how one is selected (`bilingual-product-architecture`).

Russian appears here only as data, in guillemets or code blocks.

## 1. The past tense knows the user's gender — and you don't

Russian past-tense verbs, short adjectives and participles inflect for the gender of their
subject. There is no gender-free way to say "you saved it" about one person informally:

| Form | Masculine | Feminine | Plural (any gender) |
|---|---|---|---|
| past tense | «сохранил» | «сохранила» | «сохранили» |
| short adjective | «готов» | «готова» | «готовы» |
| short participle | «сохранён» | «сохранена» | «сохранены» |

Your product does not know the user's gender, must not ask for it to write a sentence, and
would still be wrong for the users who answer neither. So **every sentence that refers to what
the user did, or what the user is, must be phrased so that no word in it agrees with them.**

This is invisible to anyone who has only shipped English. It is not a rare edge: it lands on
confirmations, empty states, onboarding, notification bodies, and the whole first-person voice
of a conversational product.

### The neutralization toolbox

| Instead of | Write | Why it works |
|---|---|---|
| «Ты отправил заявку» | «Заявка отправлена» | the participle agrees with the **noun**, not the person |
| «Ты сохранил изменения» | «Изменения сохранены» / «Сохранено» | impersonal; the neuter short participle takes no subject |
| «Ты не смог загрузить файл» | «Не удалось загрузить файл» | impersonal construction — no subject to agree with |
| «Почему ты ушёл с прошлого места?» | «Что стало причиной ухода с прошлого места?» | past-tense verb replaced by a noun phrase |
| «Почему ты решил сменить работу?» | «Почему хочешь сменить работу?» | present tense has no gender |
| «Ты уверен?» | «Точно?» / «Подтвердить?» | drop the predicative adjective |
| «Ты добавил 3 маршрута» | «Добавлено маршрутов: 3» / «Маршруты добавлены» | impersonal, count moved out of the clause |

Four reliable moves, in order of preference: **present or future tense**; **impersonal
constructions** («не удалось …», «нужно …», «можно …»); **passive/neuter short participles**
(«готово», «сохранено», «отправлено», «записано»); **imperatives** («пришлите резюме»,
«выберите зону»), which are neutral in both address forms.

### The formal address form gives you this for free

`вы` (formal) takes **plural** agreement, and the plural past tense has no gender: «вы
отправили», «вы уверены». `ты` (informal) takes **singular** agreement, so every past-tense
sentence about the user is a coin flip. See §2 — the two decisions are coupled, and picking
`ты` means buying this entire section in full.

### The bot's own voice is a separate decision

A first-person product voice ("Got it", "I've saved that") is itself gendered in the past
tense: «понял» / «поняла», «записал» / «записала». Unlike the user, the persona's gender is
yours to fix. Two valid policies — pick one and write it down:

1. **Declared persona gender.** The product speaks with one consistent grammatical gender.
   Cheap, warm, and every new string must match it.
2. **No persona gender.** The product never uses a past-tense first person: «Понятно» not
   «Понял», «Готово» not «Сделал», «Передано в поддержку» not «Передал в поддержку».

What is forbidden is mixing them, which reads as two different products taking turns.

### The constraint must be pushed into generated text, not just the catalogue

**Neutralizing every static string does nothing if a model writes the variable you
interpolate into it.** A model asked for a friendly Russian sentence will reach for the past
tense and pick a gender, and it will do so inside `{{summary}}`, `{{strategy_note}}` or a
generated button label — inside a frame you already proved neutral. The bug ships as a
perfectly grammatical sentence that is wrong for half your users, on a surface no reviewer
re-reads because the static copy passed review.

- The gender-neutrality rule and the address form (§2) go **into the generation prompt** for
  every producer of Russian text: clarification questions, summaries, generated labels,
  notification bodies, support macros.
- The same applies to any service that returns display-ready Russian rather than a key.
- Assert at the seam where you can: reject or re-ask on a generated string that contains a
  first-person or second-person past-tense form.
- If the `llm-pipeline-rules` skill is installed, treat this as one of the output constraints
  it governs; otherwise state it in the prompt template and in the review checklist.

### Finding the ones already shipped

- Read every user-referring sentence and ask one question: *does any word here change if the
  user is a woman?* That is the whole review, and it is fast once the reviewer knows to do it.
- A cheap grep over the catalogue: word-final «л», «ла», «ло» before a space or punctuation
  catches most past-tense forms. It over-matches heavily (many nouns end that way), so it is a
  triage list for a human, **not** a CI gate. `Verify:` this heuristic on your own catalogue
  before wiring it into anything.
- Fill placeholders with a female persona name during review; a masculine-defaulted sentence
  next to a woman's name is obvious on screen and invisible in the catalogue file.

## 2. Address form is one configuration point

Russian has no neutral "you". Every second-person verb, pronoun and imperative commits to
`ты` (informal singular) or `вы` (formal / plural). The choice is a product decision — but the
engineering rule is independent of which way it goes:

**Declare the address form once, next to the copy, and make every producer of Russian text
read that one declaration.** Switching the whole product should be a rewrite of one file, not
an archaeology expedition.

Producers that must read it:

- the static string catalogue;
- prompt templates for any generated Russian (§1);
- transactional email and push-notification templates;
- error and support copy, including canned support replies;
- anything a partner or service composes on your behalf.

Rules that follow:

- **Consistency inside one screen matters more than which form you picked.** A mixed screen
  reads as two products; a consistently informal one reads as a choice.
- `вы` buys gender-neutral past tense (§1). `ты` buys warmth and costs you every past-tense
  sentence about the user. Price it before deciding, not after.
- **Never switch forms by find-and-replace.** Pronouns («тебя» → «вас», «твой» → «ваш»), verb
  endings, and imperatives («пришли» → «пришлите») all change; the result of a substitution is
  broken grammar, not a translated product. It is a rewrite of every second-person string.
- Capitalized «Вы» is a formal-correspondence convention for addressing one named person. In
  product UI it reads as stiff or as a mail merge; lowercase «вы» is the usual choice. Either
  way, decide once and record it — mixed capitalization is a visible defect.
- Third-person and impersonal phrasings sidestep the choice entirely and are a legitimate
  house style for system messages: «Не удалось сохранить», «Требуется подтверждение».

## 3. Plurals: three integer categories, and the exception at 11–14

**A two-branch plural is wrong the moment Russian is added.** It does not fail loudly —
it produces broken text at specific counts nobody hand-checks.

```ts
// WRONG — encodes English grammar at the call site: renders «5 поездки», never «5 поездок».
const label = count === 1 ? "поездка" : "поездки";
// WRONG — suffix surgery on an inflected stem: «поездка» + «и» is not a word.
const label = t("trip") + (count === 1 ? "" : "и");

// RIGHT — the call site passes a number; the catalogue owns the grammar.
const label = t("trips.nearbyCount", { count });
```

The categories, and why there are three of them — the numeral governs the **case** of
everything it counts:

| CLDR category | Rule | Counted noun form | Example |
|---|---|---|---|
| `one` | `n % 10 == 1` and `n % 100 != 11` | nominative singular | «1 поездка» |
| `few` | `n % 10` in 2–4 and `n % 100` not in 12–14 | genitive singular | «2 поездки» |
| `many` | everything else, including 0 | genitive plural | «5 поездок» |
| `other` | non-integers | genitive singular | «2,5 часа» |

```ts
// Russian integer plural rule (CLDR). n is a non-negative integer.
function russianCategory(n: number): PluralCategory {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return "one";
  if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return "few";
  return "many";
}
```

The mod-100 exception is the part everyone gets wrong:

| count | category | rendered |
|---|---|---|
| 1, 21, 101 | `one` | «21 поездка» |
| 2, 3, 4, 22 | `few` | «22 поездки» |
| 0, 5–20, 25 | `many` | «11 поездок», «0 поездок» |
| **11, 12, 13, 14** | **`many`** | «12 поездок» — a naive mod-10 rule says `one`/`few` here |
| 111, 112 | `many` | the exception is on mod 100, so it recurs every hundred |

Rules that fall out:

- **Store the whole sentence per category, not just the noun.** The verb agrees too:
  «1 поездка найдена» / «2 поездки найдены» / «5 поездок найдены». A catalogue that pluralizes only
  the noun and concatenates the rest is broken at `one`.
- **`.other` must exist even though no integer selects it.** Fractions use it — Russian writes
  the decimal with a comma: «2,5 часа» (genitive singular, like `few`). It is also the
  resolver's fallback when an exact category is missing, so its absence turns a small gap into
  an unresolved key.
- **A counted noun interpolated into a longer sentence needs its own plural resolution.** A
  frame like `{{delta}} {{unit}}` where `unit` is «уровень / уровня / уровней» must run the
  resolver for that noun with that count — not pick one form and hope.
- **Test 0, 1, 2, 5, 11, 21 and 111 at minimum.** A bug that only appears at 11 survives every
  hand-check that stops at three.
- **Zero is a grammar question, not a product one.** Russian puts 0 in `many`. If the product
  wants «Рядом пока пусто» instead of «0 поездок рядом», that is a *different key* chosen by the call
  site, never a fourth branch inside the plural.
- Spelled-out numerals inflect for case and (for one and two) gender — «одна поездка», «два
  дня» / «две недели». Do not spell numerals out inside interpolated frames; render digits.

## 4. A glossary, so one concept is always one word

Russian offers several plausible words for most product nouns, and two contributors will
choose two of them in the same week. Write the mapping down beside the catalogue and treat it
as binding — an off-glossary synonym is a review comment, not a matter of taste.

The shape of that mapping, illustrated on a made-up carpooling app:

| Concept | Term | Applies to |
|---|---|---|
| trip | «поездка» | tab title, statuses, empty states |
| route | «маршрут» | map labels, saved-items list |
| pickup point | «точка встречи» | map, notifications |
| driver | «водитель» | profiles, trip cards |
| crew | «экипаж» — a deliberate coinage for the product's recurring ride group | tab name, group screens, invitations |

- **Fix the product's own concept nouns first** — the tab name, the object the app is about.
  Those drift hardest because they appear everywhere and everyone paraphrases them.
- **Record the grammatical gender of each term.** Renaming «заявка» (feminine) to «отклик»
  (masculine) changes every adjective, participle and past-tense verb agreeing with it across
  the catalogue. Like the address form, a glossary change is a rewrite, not a substitution.
- **Decide loanword versus native form once**: «аккаунт» or «учётная запись», «пуш» or
  «уведомление», «локация» or «местоположение». Both are correct Russian; mixing them inside
  one product is what reads as sloppy.
- **What stays in English** is a glossary entry too: the product name and brand tokens,
  established technical terms your audience expects in Latin script, and anything on the
  do-not-localize list. Transliterating the product name is a decision, never a default.

### Enum labels agree with a noun — so they are not reusable

Attribute labels are adjectives, and an adjective is written to agree with one specific noun:

```ts
// These agree with a FEMININE noun («машина» / «поездка»).
"enums.ride.quiet":   "Тихая",
"enums.car.compact":  "Компактная",
```

Reuse the same value beside a masculine or neuter noun and the agreement is wrong: «Спокойная
характер» is broken. The frame `"{{value}} энергия"` works; `"{{value}} характер"` does not,
with the same values.

- An enum label set is valid **only in frames whose noun has the same gender**. A second frame
  with a different noun needs its own key set, or a frame that keeps the label standalone (a
  badge, a chip, a table cell with the noun in the column header).
- Never derive a display label from a wire value by capitalizing it. Enum values render
  through the catalogue, in their own namespace, so a missing label is caught by the same
  parity check as everything else.

## 5. Interpolated values land in a fixed grammatical case

A placeholder inherits whatever case the sentence around it demands — and the value arrives in
whatever case its source produced, usually nominative. Russian names, place names and common
nouns all inflect, and you cannot inflect them at runtime with string surgery.

```ts
// WRONG — the frame demands the dative; the value arrives nominative.
"trips.sendingRequestTo": "Отправляем запрос {{name}}"   // → «Отправляем запрос Мария»

// RIGHT — restructure so the value sits in the nominative.
"trips.sendingRequestTo": "Запрос отправляется · {{name}}"
"trips.sendingRequestTo": "Кому отправляем запрос: {{name}}"
```

- **Design frames that keep interpolated values in the nominative**: put them after a colon,
  a separator or a label, or on their own line. This costs one design decision and removes a
  whole class of defects.
- Greetings are safe because the nominative doubles as the address form: «Привет, {{name}}»,
  «Доброе утро, {{name}}».
- **Never interpolate a translated noun into a translated sentence.** Its case is fixed by the
  frame, and every word agreeing with it changes too. One key per complete sentence.
- Do not build a sentence by concatenating translated fragments. Word order *and word form*
  are properties of the whole sentence in an inflecting language.
- Numbers, dates and currency go through the platform's locale-aware formatter: space as the
  thousands separator, comma as the decimal separator («1 234,5»), day-first dates, 24-hour
  time, currency symbol after the amount.

## 6. Length, sentence case, and what a translated layout does

Russian runs longer than English — roughly +10–20% for prose, and far more for short labels,
where a four-character English button becomes a fifteen-character Russian one. Words are long,
compounds do not break, and default hyphenation is usually off.

- Never size a control to fit the English string. Let labels wrap, or set a minimum and let
  the container grow.
- Never truncate the only label on a control: a Russian word cut mid-stem is unreadable, not
  merely ugly.
- Review the layout in Russian on the narrowest supported screen — that is where clipping is.
- Russian uppercases cleanly (`«ё» → «Ё»`), so all-caps is safe for short stat labels and
  eyebrows. It is not safe for sentences: caps strip the ascender/descender shapes readers use
  and slow reading noticeably.

**Sentence case, not Title Case.** English Title Case has no Russian equivalent. Headings,
buttons, tabs, menu items, table headers and card titles capitalize the first word and proper
nouns only.

| Wrong | Right |
|---|---|
| «Завершить Поездку» | «Завершить поездку» |
| «Настройки Уведомлений» | «Настройки уведомлений» |
| «Мои Сохранённые Маршруты» | «Мои сохранённые маршруты» |

Capitalizing every word is the single most recognizable tell of an interface translated
word-by-word from English, and it survives every spellcheck.

## 7. Typography Russian actually uses

These are not preferences; they are the conventions of the writing system, and getting them
wrong reads as a foreign product.

| Element | Use | Not |
|---|---|---|
| Quotation marks | «ёлочки» as the outer pair; „лапки“ nested inside | `"straight"`, `“English curly”`, `'apostrophes'` |
| Dash in a sentence | em dash `—` with spaces around it, standing in for the missing copula: «Маршруты — в планах» | an unspaced em dash (English style), or a hyphen |
| Numeric range | en dash `–`, no spaces: «5–10 км» | «5 - 10» |
| Hyphen | intraword only: «QR-код», «пуш-уведомление» | as a dash |
| Ellipsis | one character `…`, or three dots — **pick one** | both, mixed across the catalogue |
| Non-breaking space | between a number and its unit («5 км»), after one- and two-letter prepositions | a plain space that lets «5» end a line alone |

**The optional letter «ё».** Russian permits writing «е» where «ё» belongs, and both are
correct. The engineering rule is *consistency*, decided once and recorded next to the
glossary:

- Pick a policy — always «ё», or «ё» only where it disambiguates («все» / «всё», «узнаем» /
  «узнаём») and in proper nouns — and apply it to the whole catalogue. Mixed usage inside one
  screen is a visible defect; either policy applied consistently is invisible.
- Whatever the display policy, **normalize «ё» to «е» on both sides of any comparison**:
  search, filtering, sorting, deduplication, slug generation, and matching user input against
  stored values. Users type both.
- The same normalization belongs on the final «й» / «и» distinction only if your data source
  is unreliable — do not add it speculatively.

## 8. Keys, rotation, and the honesty of repeated text

- **Keys are stable identifiers; code references the key, never the literal.** Rewording is
  then a copy edit, not a code change, and a second locale is a second catalogue rather than a
  refactor. Renaming a key is a migration; rewording its value is not.
- **Rotate high-frequency lines.** Status lines the user sees many times per session — waits,
  progress, acknowledgements, a repeated clarification lead-in — read as robotic when they are
  byte-identical every time. Give those specific keys a small set of alternates and pick one
  per occurrence (random, or by position in the sequence). List which keys rotate; do not
  rotate everything.
- **Every variant must be interchangeable in every frame**: same address form, same
  gender-neutrality, same length band, same register. A rotation set is where an off-voice or
  gendered line hides, because reviewers read variant 0 and stop.
- Copy lives outside the code in one source of truth per locale, so a Russian-now /
  English-later product swaps by locale rather than by rewrite.

## 9. A native review pass before launch

**A native-speaker read-through of the complete Russian surface is a launch gate, not a nice
to have** — including when the copy was written by a fluent speaker. Catalogues are written
key by key over months and read screen by screen in seconds; the defects live in the seams
between keys, which no author ever sees.

Run it **in the rendered UI**, not in the catalogue file, with placeholders filled by real
values — including a female persona name, a long name, and counts at the plural boundaries.

Give the reviewer the checklist, not just the build:

1. Does any sentence about the user change form if the user is a woman? (§1)
2. Is the address form the same everywhere, including notifications, emails, errors and
   anything a model generated? (§2)
3. At counts 0, 1, 2, 5, 11, 21 — is the whole sentence right, verb included? (§3)
4. Is every domain noun the glossary term, and does every adjective agree with its noun? (§4)
5. Any Title Case, any straight quotes, any unspaced em dash, any mixed «ё»? (§6, §7)
6. Any sentence that is grammatical but reads as translated — a calque of English word order,
   a literal rendering of an English idiom, a hedging phrase Russian does not use?
7. Any placeholder sitting in the wrong case? (§5)

Record who did the pass and when. Re-run it on any surface where the copy source changed —
especially prompts, which change more often than catalogues and are reviewed less.

## 10. Definition of done

- [ ] No sentence about the user contains a word that agrees with their gender; the
      neutralization was done by rephrasing, not by picking a default.
- [ ] The gender-neutrality rule and the address form are stated in the prompt of every
      producer of generated Russian, and in any contract with a service returning display text.
- [ ] The first-person product voice follows one declared policy (fixed persona gender, or no
      past-tense first person) across every string.
- [ ] One address form, declared in one place, applied to catalogue, prompts, email, push,
      errors and support copy.
- [ ] Count-sensitive strings carry `.one` / `.few` / `.many` / `.other`, hold the **whole**
      sentence per category, and were eyeballed at 0, 1, 2, 5, 11, 21.
- [ ] No `count === 1` ternary and no suffix concatenation anywhere in the diff.
- [ ] Every domain noun matches the glossary; new terms added with their grammatical gender.
- [ ] No enum label reused beside a noun of a different gender.
- [ ] Every interpolated value sits in the nominative, or the frame was restructured so it can.
- [ ] Sentence case throughout; no Title Case in headings, buttons, tabs or menus.
- [ ] Guillemets, spaced em dashes, en-dash ranges, one ellipsis style, one «ё» policy;
      «ё» normalized on both sides of every comparison.
- [ ] Layout checked in Russian on the narrowest screen — no clipping, no truncated single
      label.
- [ ] Rotating variants all share the address form, gender-neutrality and length band.
- [ ] Native review pass completed on the rendered UI against the §9 checklist, and recorded.

## Project delta

The consuming repo supplies:

- The **address form** (`ты` or `вы`), whether «Вы» is capitalized, and the single file or
  constant that declares it.
- The **persona policy** for first-person product voice: a fixed grammatical gender, or none.
- The **glossary** — the product's concept nouns, their agreed Russian terms, each term's
  grammatical gender, and which words deliberately stay in English or Latin script.
- The **«ё» policy** and the ellipsis choice, plus where the normalization for search and
  matching lives.
- Which surfaces carry **model-generated or service-supplied Russian**, and where the
  neutrality and address-form constraints are stated for each.
- The list of **keys that rotate**, and how a variant is selected.
- The **plural resolver's** location and the command that exercises the boundary counts.
- Number, date and currency formats if they differ from the platform locale defaults.
- Who performs the **native review pass**, at which point in the release process, and where
  the result is recorded.
