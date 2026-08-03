---
name: bilingual-product-architecture
description: Structure a product and its agent skills to work in two languages at once — separate the conversation locale (the language the system talks to the user in) from the artifact locale (the language the produced deliverable is written in), declare a key-set source of truth that may differ from the default display locale, fail the build on catalogue gaps, gate generated text so it stays monolingual in both directions, and write skill descriptions that fire in either language. Use when the user says "make it bilingual", «сделай двуязычным», "add Russian", "the bot replied in the wrong language", "the output is half English", "which language should the result be in", "mixed-language output", "a missing key shipped English to Russian users", or "my skill never triggers when I write in Russian". Also use whenever a second locale catalogue, a locale parameter on a prompt template, or a language-detection step appears in the work.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Bilingual product architecture

**Core rule: every string the product emits has an audience, and its language is decided by
that audience — never by one global `locale` variable. A bilingual product carries several
independent locale decisions, and collapsing them into one is the defect this skill exists
to prevent.**

Two languages is not one language plus a translation table. It is a product where the
person reading a screen, the person being asked a question, and the person who will read
the generated deliverable can be three different audiences speaking two different
languages — sometimes inside a single request.

Items marked `[!]` caused a real production incident when missed. They are not style
preferences.

## Scope

This skill defines only: **which locale axes a bilingual product carries and who decides
each; how conversation language and artifact language are separated, plumbed and defaulted;
how the key set, the fallback chain and the default display locale relate; how catalogue
parity and monolingual output are enforced as failures rather than hopes; what is never
localised; the prose language of the repository itself; and how to write and validate an
agent skill description that triggers in either language.**

It does not define catalogue file layout, plural-category resolution, interpolation or
layout expansion — if the `i18n-conventions` skill is installed, follow it for that
machinery. It does not define Russian wording, gender or case (`ru-ui-strings`), tone
transfer between the two languages (`ru-en-tone-transfer`), or market document norms
(`ru-market-job-application-norms`). For general description craft and eval methodology, if
the `skill-authoring` skill is installed follow it, and treat §9 here as the bilingual
delta. Otherwise follow the project's own conventions.

Russian appears below only as example data, inside guillemets or code blocks. Every
instruction, heading and explanation is English — including in a product whose entire UI is
Russian (§8).

## 1. The locale axes

| Axis | Decides | Chosen by | Set from |
|---|---|---|---|
| **Artifact locale** | the language of the thing the product *produces* — a letter, a report, an export, a generated document | product rule, per request | the language of the artifact's **target** (the document it answers, the market it is sent to) |
| **Conversation locale** | the language the system *addresses the user* in — questions, coaching notes, explanations, status, chrome | the user | the user's profile or UI choice, never the artifact's target |
| **Register mode** | the norms, not the words — formality, self-promotion calibration, what personal data is acceptable | market | artifact locale + market; orthogonal to both language axes |
| **Key-set source of truth** | which keys must exist in every catalogue; what the parity guard is derived from; what the runtime fallback reads | engineering | the locale with the fewest plural categories (§4) |
| **Default display locale** | what a first-run user sees before choosing anything | product / launch market | the launch market's language (§4) |

A sixth decision — the language the repository itself is written in — is §8.

**The anti-pattern is one field.** A single `locale` threaded into every step reads as
economical and is the direct cause of §2 and §6. Two of these axes routinely disagree in a
single request, and two more routinely disagree for the whole product's lifetime.

## 2. Conversation locale vs artifact locale

`[!]` **A pipeline that derived one `locale` from the submitted document's detected
language shipped this to real users:** clarifying questions asked in the document's
language to a user who had never chosen it, wrapped in the product's native-language
chrome; a user-facing coaching note in the same foreign language; and a deliverable that
was *mixed* — a native-language greeting «Здравствуйте!», a foreign-language body, and a
native-language sign-off «С уважением,». The coarse locale check in the evaluation suite
passed the mixed deliverable, because two native-script words do not move a script ratio
computed over a whole page (§6).

The product rule "the output follows the language of the target document" was only ever
about the **artifact**. Everything the system says *to the user* is conversation and
follows the user.

### 2.1 Classify every surface before you plumb it

| Surface | Axis | Why |
|---|---|---|
| The generated deliverable itself | artifact | its reader is the target audience, not the user |
| Verbatim quotes embedded in the deliverable | artifact | they are part of the artifact's text |
| Clarifying questions the system asks | **conversation** | the user answers them |
| Coaching notes, positioning notes, explanations of the result | **conversation** | this is the system talking about the artifact, not the artifact |
| Per-item rationale attached to the artifact ("why this paragraph is here") | **conversation** | it is commentary for the user, even though it is rendered next to artifact text |
| Warnings, blockers, recommendations | **conversation** | a user cannot act on a warning they cannot read |
| Buttons, menus, status, errors, chrome | **conversation** | UI is always the user's language |
| Intermediate internal guidance between steps | neither — do not gate it | it is re-rendered into the artifact language downstream; asserting a language on it produces false failures |
| Evidence extracted to feed the artifact | artifact | its output lands in the artifact |

The two failure modes are symmetrical and both are real: **coaching nobody can read**, and
**a deliverable in the wrong language**. Getting one axis right does not protect the other.

### 2.2 Plumbing rules

1. **Two explicit fields on the request contract**, not one — `artifact_locale` and
   `conversation_locale`.
2. **`conversation_locale` defaults to `artifact_locale` when empty.** This keeps every
   single-locale caller, test and monolingual code path unchanged, and makes the split a
   backward-compatible addition rather than a migration.
3. **The channel decides both; downstream steps only receive them.** Language selection is
   a product decision made where the user's identity is known. A generation step that
   infers its own language from its input has just re-created the single-variable bug
   inside itself.
4. **Each step is annotated with the axis it serves**, in the step's own specification, and
   changing a step's axis is a versioned change to that specification — not an edit.
5. **The register axis rides separately.** The same request can legitimately be: artifact in
   language B, conversation in language A, register norms of B's market. Folding register
   into the language field is rejected for the same reason as §1 — they disagree.
6. **Assert the split in the evaluation suite, per case.** A case carries an expected
   conversation locale, and the check asserts the coaching note *and* the clarifying
   questions are in it, not just that the artifact is in the artifact locale. Without that
   assertion the split is a claim.

## 3. Where each value comes from

| Value | Source | Trap |
|---|---|---|
| Artifact locale | detected language of the target document, or an explicit product rule | detection on a short or code-heavy input is unreliable — carry a confidence and fall back to the user's locale rather than guessing |
| Conversation locale | the user's stored preference; the deployment default until per-user preference exists | never derive it from content the user pasted |
| Default display locale | a product decision | **do not auto-detect the device locale** when the default is deliberate — detection silently overrides the decision |
| Persisted user choice | namespaced storage key, e.g. `<product>:locale` | validate through a type guard before use; a stale or hand-edited value must fall back to the default, never index into an undefined catalogue |

Read the persisted choice **before first paint** — a flash of the wrong language is the
cheapest bug on this list to fix and the most visible one to leave.

## 4. Key-set source of truth ≠ default display locale

These are two different decisions and they are *allowed to disagree*. The common correct
configuration is exactly the inverted one: **English is the key set, the launch market's
language is the default display locale.**

| | Key-set source of truth | Default display locale |
|---|---|---|
| Decides | which keys must exist everywhere, what the parity guard derives from, what the runtime fallback reads | what a first-run user sees |
| Chosen by | engineering | product / launch market |
| Changing it | re-points the guard and the fallback — rare, deliberate | cheap, a product call |

Pick the key set as **the locale with the fewest plural categories** — in practice English.
The superset only works in one direction: a two-category catalogue can be covered by a
three-category one (`.one`/`.other` plus `.few`/`.many` on top), but a source locale that
demanded `.few` and `.many` would force every two-category locale to carry duplicate dead
entries just to satisfy the guard. Secondary reason: the fallback catalogue is the one
every contributor can proofread.

**The inversion is precisely what makes §5 an incident-grade rule.** With the fallback in a
different language from the default, one missing key does not produce a blank — it produces
a screen that is mostly the default language with one sentence of the fallback language in
the middle of it.

## 5. Catalogue parity is a build failure

`[!]` **A missing key that resolves through a runtime fallback silently ships the wrong
language to real users.** The screen renders, nothing throws, no test fails, and the only
detector is a user noticing. In a typed language the guard is four lines and needs no
dependency:

```ts
import { en } from "./locales/en";
import { ru } from "./locales/ru";

// The source-of-truth locale defines the key set.
export type CatalogKey = keyof typeof en;

// Compile-time guard: `ru` must define every key `en` does. A gap surfaces as a type
// error during `tsc --noEmit`, never as a runtime fallback. Extra keys — the `.few` /
// `.many` variants the other locale needs — are allowed on top.
const _ruCoversEn: Record<CatalogKey, string> = ru;
void _ruCoversEn;
```

- The guard runs in **the command CI already gates on** (`typecheck`, `build`). A check
  living in a script nobody runs is not a guard.
- The allowance is **asymmetric by design**: extra plural variants in the richer locale are
  fine; a missing key in either direction is not.
- Untyped stack: replace the assertion with a test that diffs key sets in both directions
  and fails on any asymmetry other than the permitted extra plural suffixes.
- Keep the runtime fallback chain as a *crash guard*, not as policy, and make its last
  resort render **the key itself** — a screen showing `profile.saveError` is a bug report
  writing itself, while an empty string is invisible.

## 6. The monolingual output gate

Applies to text a model produces, where no catalogue exists to enforce anything.

**A generated artifact must be in exactly one language.** Contamination happens in both
directions, and the two directions need different detectors.

`[!]` **A script ratio is not a monolingual gate.** The mixed deliverable in §2 passed the
evaluation's ratio check and passed the model critic reviewing the text; a couple of
foreign words do not move a ratio, and a critic asked "is this good" does not reliably
answer "is this one language". The gate must be **deterministic**, and it must run over the
delivered artifact before delivery.

### 6.1 Asymmetric detection

| Artifact locale | Detector | Threshold that worked | Rationale |
|---|---|---|---|
| Latin-script language | longest run of consecutive Cyrillic letters | run ≥ 4 letters fails | a fully rendered Latin-script artifact has **no** natural Cyrillic; any Cyrillic word is a leaked greeting, sign-off or untranslated term |
| Cyrillic-script language | longest run of consecutive Latin *natural-language* words | run ≥ 4 tokens containing ≥ 2 all-lowercase words of ≥ 4 letters fails | Latin is **normal** here — product names, technologies, acronyms. Only a run that reads as a sentence is a leak |

`Verify:` those thresholds are tuned on one Russian/English corpus. Re-check them against
your own text before trusting the numbers; the asymmetry is the transferable part.

### 6.2 The false positives that cost more than the bug

`[!]` **An over-eager Latin-run detector fired on normal professional register and its
rewrite feedback instructed the generator to delete a load-bearing technical term.** The
detector split on every non-letter, so `«agile / cloud-native (CI/CD)»` counted as a
five-word English phrase. Four refinements fixed it, and every one of them is the kind of
detail that is only ever learned in production:

- **A hyphenated compound modifier is one token**, not two — `cloud-native`, `on-premise`,
  `data-driven`. Keep an internal hyphen inside the token; every other non-letter still
  separates.
- **An ALL-CAPS acronym is transparent to the run** — it neither lengthens nor breaks it.
  It is a label, not language. Note `CI/CD` is two tokens, both acronyms, because the slash
  separates.
- **An allowlisted technical term counts as one word but never as natural language.**
  Transparent is wrong here: a transparent token *shortens* a genuinely leaked English run
  that happens to contain one, and "we deliver enterprise software solutions" then counts
  zero words.
- **Match multi-word allowlist entries across adjacent tokens**, not only in their
  hyphenated spelling. Otherwise `cloud native serverless microservices` fails while the
  hyphenated spelling of the same phrase passes — a verdict decided by a keystroke.

A gate that punishes correct text is worse than no gate: it teaches the generator to
degrade the artifact. Every rail should be a no-op on clean output and conservative by
design — prefer a false negative to breaking an honest artifact.

### 6.3 Normalize before you scan

Scan a canonicalised copy: NFKC → strip zero-width and bidi characters → fold Cyrillic
lookalikes toward Latin → lowercase. Fold **both** the text and every needle the same way,
or a pure-Cyrillic needle can never match a folded text.

```
а→a  е→e  о→o  р→p  с→c  х→x  у→y  к→k  т→t  в→b  н→h  м→m
```

Fold *toward Latin*, not the other way: a genuinely Latin token stays byte-for-byte
unchanged, so every other Latin-keyed check keeps matching with no further change.
`Not an issue:` the fold is idempotent and a no-op on clean prose — an honest text carries
no zero-width characters and reads identically after a uniform letter fold, so no clean
output changes verdict.

Keep the confusable map deliberately small — only letters that both have a lookalike and
appear in something you actually match on.

### 6.4 Gate hygiene

- **Scan the delivered text once.** If the artifact exists both as a flat message and as a
  derived segment view, concatenating them hands every text-scanning check the artifact
  twice: occurrence-counting checks then read one mention as two. Prefer the authoritative
  flat text; fall back to the joined segments only when it is absent.
- **A failure carries a stable typed kind plus a human message.** Classify on the kind;
  feed the message verbatim to the rewrite loop and the logs. Never branch on message
  text — re-wording a message must not change behaviour.
- **The coarse dominant-script check is still useful for the conversation surfaces**, where
  the bar is "did this come back in the right language at all". Lenient, asymmetric
  thresholds, e.g. Cyrillic ratio > 0.4 for a Cyrillic-target surface and < 0.15 for a
  Latin-target one; an unknown expected locale asserts nothing rather than blocking on what
  cannot be judged.
- Run the strict artifact gate and the coarse conversation check as **separate** named
  failures. They fire on different surfaces for different reasons.

## 7. What is never localised

| Never translate | Because |
|---|---|
| Enumeration values on the wire, and any field sent **to** a service | the receiver parses them; a localised value is a broken payload |
| Identifiers, slugs, keys, tokens | they are addresses, not text |
| Route paths and deep-link segments | localised routes fork the URL space and break saved links |
| Storage keys, feature-flag names, test ids | they must be stable across locales and versions |
| Brand and product tokens | the name is the same word everywhere |
| Error codes (the code, not its message) | the code routes handling; only its display string is translated |
| Log lines, metric labels, analytics event names | read by engineers and machines; localised logs are ungreppable |

The rule underneath: **if a string crosses a process boundary as data, it is not UI text.**
The same concept often needs both — a stable code on the wire and a `errors.<code>`
catalogue entry for display. Keeping them separate is the entire point. Enumerations render
through the catalogue under their own namespace, never as a capitalised wire value.

Two additions specific to bilingual products:

- **The do-not-localise list binds the model too.** A generated artifact must not translate
  a product name, a technology or a proper noun into the artifact's language. This is also
  why the monolingual detector for a Cyrillic-script artifact must tolerate Latin tokens
  (§6.1) — the correct behaviour and the contamination look alike to a naive detector.
- **A name that exists in two scripts is still one name.** Do not translate it; do carry
  both spellings anywhere it functions as a search or trigger token (§9).

## 8. One prose language for the repository

Code, comments, documentation, commit messages, log lines, agent guides and skills are
written in **one** language — the engineering language of the project — even when every
user-facing string ships in another. The product's language appears in the repository only
as *data*: catalogue values, test fixtures, examples in guillemets or code blocks.

- Mixed-language identifiers and log messages are ungreppable, and a bilingual codebase
  splits its own history in half.
- A skill or guide *about* a language is written *in* the engineering language *about* that
  language. This document is the worked example.
- Tests that assert user-facing copy pin the **key**, not the text. A test pinned to a
  Russian sentence fails on a copy edit and tells you nothing about behaviour.

## 9. Skill descriptions that trigger in either language

A skill's `description` is the only part of it in context when the agent decides whether to
load it. In a bilingual product the user will type the domain noun in their own language
inside an otherwise-English session, and switch mid-sentence. A description that carries
one vocabulary loses every prompt phrased in the other.

Four moves, all in one English paragraph:

1. **Paired tokens in a single list.** For each job the skill does, carry the native word
   and the English word adjacent, so one list covers both vocabularies:
   `… (they may say «отчёт», «выгрузка», "report", "export") …`
2. **Two quoting conventions, deliberately.** Guillemets for one vocabulary, straight
   quotes for the other. The pairing stays visually separable, the prose stays
   unambiguously English, and neither set of tokens is mistaken for instruction text.
3. **Both spellings of a name.** A product whose name has a native-script form and a Latin
   transliteration must carry **both** — users type each, and search matches neither when
   only one is present. Example pattern: the skill name and domain use the transliteration
   `<product>`, and the description also carries `«<продукт>»` once, as data.
4. **A non-lexical fallback keyed on what is present, not on what is said.** The strongest
   trigger is not a word:

| Signal | Clause to add |
|---|---|
| The skill drives a tool server | "Also use when the `<product>` tools (`list_items`, `create_item`, `publish_item`, …) are available in the session and the task involves `<domain>` — even if the user never says the product name" |
| The skill governs a file type | "Also use whenever a `<file>` is being read or edited" |
| The skill governs a directory | "Also use when work touches `migrations/` or `charts/`" |

This clause is what rescues the case a vocabulary gap defeats: the tools, the open file or
the target directory say what the sentence did not, in any language.

Two rules that keep the description working:

- **Keep the prose English.** A description written half in each language reads as noise to
  the loader and mistriggers; the other language appears only as quoted data.
- **Do not stuff.** A token list with no "when" mistriggers. The ceiling is 1024 characters
  and a good description lands at 400–800.

### 9.1 Content language is a separate decision from conversation language

Inside a bilingual skill, restate §2 in the skill's own terms, because the agent will
otherwise mirror the prompt: **write the produced content in the audience's language,
whatever language the conversation happens in**, set the artifact's declared language field
to match, and confirm when it is not obvious. A user writing to the agent in one language
routinely wants an artifact in the other.

### 9.2 Validate the triggering, do not assume it

A skill whose evaluation cases are all in English proves only that the English half of the
description works. Make the eval set **deliberately mixed-locale**:

- [ ] At least one case whose prompt is written entirely in the non-English language, in the
      sloppy register users actually type — lowercase, no punctuation, the native form of
      the product name, native domain nouns.
- [ ] At least one case in each language that requires reading or editing something that
      already exists, so real identifiers and read-before-edit are exercised, not just
      composition.
- [ ] At least one **negative** case: the action cannot be completed here, and the correct
      behaviour is to say what is missing, not to fabricate a success or invent facts. Put
      it in the non-English language if that is where the audience is.
- [ ] Where the prompt language and the artifact's audience differ, assert **both** — the
      artifact in the audience's language and the reply in the user's — so a run that
      mirrors the prompt language fails visibly.
- [ ] Assertions are observable properties (which fields, which language, which defaults,
      which claim was *not* made), one property each — never a phrase from the skill body
      quoted back at it.

## 10. Procedure — adding a user-facing surface

1. **Name the audience** of the text in one sentence. If the answer is "the user", it is
   conversation. If it is "whoever receives the artifact", it is artifact. If you cannot
   answer, the surface is doing two jobs and should be split.
2. **Pick the axis** from §2.1 and record it next to the surface's definition.
3. **Thread the value from the channel**, never inferred locally.
4. **Static text**: add the key to the source-of-truth catalogue and to every other
   catalogue, with all plural categories that locale needs; run the parity check (§5).
5. **Generated text**: state the target language in the step's specification, and add the
   surface to the monolingual gate (artifact) or the dominant-script check (conversation)
   per §6.
6. **Check the do-not-localise list** (§7) for every identifier, enum and name in the
   surface.
7. **Add an evaluation case where the two axes disagree** — conversation in one language,
   artifact in the other. That case is the only thing that keeps the split alive.

## 11. Definition of done

- [ ] Every user-facing surface added or changed in the diff is classified as artifact or
      conversation, and the classification is written down, not remembered.
- [ ] Both locale fields exist on the request contract; the conversation value defaults to
      the artifact value when empty; no step infers its own language.
- [ ] No global single `locale` variable feeds both a user-facing message and a generated
      artifact.
- [ ] Key-set source of truth and default display locale are both stated explicitly, and
      the parity guard runs in the command CI gates on.
- [ ] Every new key exists in every catalogue; the build fails on a gap; the runtime
      fallback's last resort renders the key, never an empty string.
- [ ] The monolingual gate runs deterministically over the delivered artifact, in the
      direction-appropriate form, over normalised text, once.
- [ ] The gate is a no-op on a clean sample of real output — verified against actual
      correct text carrying technical terms and acronyms, not only against a leak fixture.
- [ ] Nothing on the do-not-localise list was translated by code, catalogue or model.
- [ ] All prose in the diff — comments, docs, logs, commit message — is in the repository's
      one prose language; the product language appears only as data.
- [ ] Any skill description touched carries paired tokens in both vocabularies, both
      spellings of any name, and a non-lexical fallback.
- [ ] The evaluation set includes a case in each language, a case where the axes disagree,
      and a negative case.

## Project delta

The consuming repo supplies:

- **The two languages**, and which one is the engineering prose language.
- **The axis assignment for every existing surface** — which are artifact, which are
  conversation, and which are exempt internal fields.
- **The names of the two contract fields** and where the channel sets them.
- **The register modes** the product recognises and what each one changes.
- **The key-set source of truth and the default display locale**, and whether device-locale
  detection is on.
- **The exact command that runs the parity check**, and the CI job that gates on it.
- **The technical-term allowlist and acronym conventions** the monolingual gate must
  tolerate, plus the tuned thresholds for this corpus.
- **The project's do-not-localise additions** — wire enums, id namespaces, brand tokens.
- **The evaluation harness** — where cases live, how a case declares its expected
  conversation locale, and who reviews a new case.
- **The product's name in both scripts**, for use in skill descriptions and search.
