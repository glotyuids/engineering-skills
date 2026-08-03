---
name: purposeful-text-writing
description: The generic method for writing any user-facing string — identify the surface, the reader and the job before drafting, then draft and cut. Covers interface copy, button labels, form labels, errors, empty states, onboarding, notifications, headlines, help text and prompts, plus writing for translation. Use when the user says "write the copy for this", "what should this button say", "reword this error message", "fill in this empty state", "rewrite this microcopy", "review the UI strings", "this text feels like filler", "write the onboarding screens", "draft a notification", "make this shorter", or whenever a change ships user-visible text. Apply this first; layer the product's own voice, vocabulary and banned words on top afterwards from a local product skill.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Purposeful text writing — every string has a job

**Core rule: every string serves a purpose. Do not write to fill a slot, satisfy a
character count, make a layout look balanced, or add polish without meaning. If you cannot
say what the string is for, you are not ready to draft it.**

This skill defines only the universal *method* for producing user-facing text: how to
identify the surface, the reader and the job, how to draft to that job, and how to cut.
It does not define a product's voice, humour level, vocabulary, banned words, address form,
reading level or language preferences — those are project-layer decisions (see
[The two layers](#the-two-layers)). It is also not a design skill: it does not choose the
component, decide the flow, or negotiate the layout. And it does not decide whether a
claim is *true* — see [Honesty](#honesty).

**Maturity note:** this method is distilled from repeated product-copy reviews, not from
incident postmortems. That is why it carries no `[!]` markers. If a string in your product
causes a real incident — a destructive action mislabelled, a consent prompt that misstated
what was collected — mark that rule in your project's own layer, where the evidence is.

## The two layers

Text is layered **generic method → product voice** in exactly the way the rest of this
library layers generic → project. Never collapse them.

| Layer | Lives in | Owns | Examples |
|---|---|---|---|
| **Generic method** (this skill) | The library | Surface, reader, job, length, specificity, structure, cutting, translation-safety | "A button is a verb plus an object, usually 1–3 words" |
| **Product voice** | A local skill or tone guide in the consuming repo | Personality, humour level, vocabulary and terminology, banned words, address form, punctuation habits, capitalisation, emoji policy, locale set | "Say *workspace*, never *account*"; "no exclamation marks"; "address the reader informally" |

Order of application, always:

1. Produce the generic draft with this skill — correct job, correct length, correct shape.
2. **Then** apply the local voice guide, rewriting word choice and register only.
3. If the voice guide would break the job (it forces a joke into an error, or a term the
   reader does not know into a first-run screen), the job wins. Report the conflict instead
   of silently picking one — that is a real finding about the voice guide.

If no local voice guide exists, say so and default to plain, neutral, concrete prose. Do
not invent a personality to fill the gap; an invented voice is the most expensive kind of
string to remove later.

## Workflow

### Phase 1 — Identify the surface

Name it before writing anything: button, headline, section title, form label, helper text,
placeholder, error, empty state, onboarding step, confirmation, toast, notification,
tooltip, marketing block, email subject, help article, or a prompt shipped to a model.

The surface sets the length budget, the tone range and the failure mode. The same sentence
that is right in help text is wrong on a button.

### Phase 2 — Identify the reader and their state

Answer four things about the person who will read this string *at this moment*:

- What do they already know — from the previous screen, the surrounding UI, the action they
  just took?
- What do they want right now?
- What might they be worried about (losing data, being charged, being wrong, being watched)?
- What can they actually do next on this surface?

A reader mid-task and a reader on first run are different readers. Text written for the
average of the two serves neither.

### Phase 3 — State the job in one sentence

Write it down, in this shape:

> This string exists so that a **`<reader in this state>`** can **`<do this / decide this /
> stop worrying about this>`**.

If the sentence comes out vague ("so that the page feels complete", "so that the section
has a heading"), **do not draft the final string yet.** Either find the real job, or
propose removing the slot. Proposing removal is a legitimate deliverable.

### Phase 4 — Choose the approach

| Dimension | Rule |
|---|---|
| **Length** | As short as the job allows — not as short as possible, and never padded to fill the box |
| **Tone** | Matched to the moment. Not globally cheerful, not globally serious. A failed payment and a finished import are not the same moment |
| **Specificity** | Concrete actions and objects over abstract claims. Name the thing, name what happens to it |
| **Context** | Do not repeat what the surrounding UI already says. The heading, the icon, the field label and the button are one sentence between them, not four |
| **Person** | Prefer the reader's action over the product's capability: "Import your contacts", not "`<product>` supports contact import" |

### Phase 5 — Draft to the job

One idea per string. Front-load the word that carries the meaning — readers scan the first
two words of a line and the first word of a button. Write full sentences where the surface
allows them; write fragments only where the surface demands them.

Write the job sentence and the draft next to each other. If the draft does not obviously
serve the job sentence, the draft is wrong — not the job.

### Phase 6 — Cut

Cutting is a separate pass. Do not merge it into drafting; you will defend your own words.

1. Remove every word that does not change meaning. Adjectives and adverbs go first.
2. Remove hedges and warm-up phrases: "please note", "simply", "just", "easily", "in order
   to", "we're sorry, but", "it looks like", "as you may know".
3. Remove defences against objections the reader is not making.
4. Remove restated context the surrounding UI already provides.
5. **Remove the whole string** if the reader still understands the surface without it. An
   empty slot is a legitimate result and often the best one.
6. Read what is left aloud. If it cannot be said in one breath, it is two strings or one
   too-long one.

### Phase 7 — Apply the product voice

Only now. Word choice, register, terminology, punctuation and capitalisation get adjusted
to the local guide; the job, the shape and the length stay as Phase 6 left them. If the
change makes the string longer, re-run Phase 6 on the result.

## Default writing requirements

- Write the job before writing the string whenever the work is non-trivial.
- Use concrete nouns and verbs.
- Prefer the reader's action over the product's capability.
- Do not invent facts, metrics, claims, guarantees, authority signals, testimonials,
  counts, dates or names. If a number is needed and unknown, mark it as a placeholder and
  say so — never guess a plausible-looking one.
- Do not pad with adjectives to make a line feel complete.
- Do not restate obvious context.
- Do not use vague verbs without objects — "handles it", "delivers", "solves",
  "transforms", "streamlines", "empowers", "leverages" — unless the sentence says what
  changes into what.
- Do not write a heading that only names the component ("Options", "Information",
  "Details") when it could name the contents.
- Do not use a placeholder as a label; the placeholder disappears exactly when the reader
  needs it.
- Do not put the only copy of a required fact in a tooltip or a hover state.
- Keep one term per concept across the whole product. Two words for one thing is a bug.

### Failure modes and their fixes

| Failure mode | Looks like | Fix |
|---|---|---|
| **Slot-filling** | A subtitle under every heading because the component has the slot | Delete the string, or delete the slot |
| **Layout padding** | A sentence stretched so two cards match in height | Let the cards differ |
| **Vague verb, no object** | "`<product>` transforms your workflow" | Say what becomes what |
| **Capability voice** | "Supports bulk export" | "Export everything at once" |
| **Blame** | "You entered an invalid date" | "Dates go in as DD.MM.YYYY" |
| **Apology padding** | "We're really sorry, something went wrong" | Say what failed and what to do |
| **Error code as the message** | A bare identifier with no sentence | Sentence first, code last, for support |
| **Restated context** | Heading "Members", empty state "No members here yet" plus a button "Add member" plus a hint "Add a member" | One of them says it; the others go |
| **Cheerful in the wrong moment** | An exclamation mark on a failed charge | Neutral and specific |
| **Undefined jargon on first contact** | An internal term in the first-run screen | Use the reader's word, or define it in place |
| **Fake progress** | "Almost done!" on an unmeasured operation | Name the step, or say nothing |

## Per-surface requirements

| Surface | Requirement | Anti-pattern |
|---|---|---|
| **Button / primary action** | Verb plus object, usually 1–3 words. Name the outcome, not the mechanism | "Submit", "OK" on a consequential action, "Click here" |
| **Destructive confirmation** | Name the object and say what is irreversible; the button repeats the verb | "Are you sure?" with "Yes"/"No" |
| **Confirmation / toast** | Short and neutral. Say what happened; offer undo where undo exists | Celebrating a routine save |
| **Error** | Calm, specific, and actionable when an action exists. What failed, why if the reader can act on it, what to do next | Blame, apology padding, "unexpected error occurred" |
| **Empty state** | Say what is missing and what would create it. One primary action | A shrug illustration and "Nothing here" |
| **Onboarding step** | Tell the reader what to do next, in order. One decision per step | Explaining the whole product before the first action |
| **Form label** | Noun phrase naming the value, in the reader's vocabulary | Reusing the database column name |
| **Helper text** | Only when the label cannot carry it. State the constraint *before* the reader hits it | Repeating the label; explaining the obvious |
| **Headline** | Concrete promise or category, not dramatic filler | "The future of work, reimagined" |
| **Notification / push** | What happened, and why it concerns the reader now. It interrupts, so the bar is higher | Re-engagement nagging with no event behind it |
| **Tooltip** | The non-obvious detail only; never the sole home of a required fact | A tooltip restating the label |
| **Loading / progress** | Name the step if it lasts long enough to notice | Invented percentages, "hang tight" |
| **Permission / consent** | What is asked, what it is used for, and what happens if the reader declines | Pressure, pre-ticked agreement, vague "improve your experience" |
| **Email subject** | The event or the ask, front-loaded, readable truncated to a few words | Curiosity-gap teasers |
| **Model prompt shipped in the product** | Same discipline: one job, no decorative instructions, no contradictory rules | Piling adjectives onto a system prompt |

## Writing for translation

Assume every user-facing string will be translated, unless the project says a locale set is
fixed. Decisions taken while drafting in the source language are what makes translation
cheap or impossible later.

1. **Write whole sentences, not fragments assembled at runtime.** Concatenating a noun into
   a sentence frame breaks in any language with grammatical gender, cases or agreement.
   Give the translator a complete sentence per meaning.
2. **One key, one meaning.** Never reuse a string because the source words happen to match:
   the same word may be a noun on one screen and a verb on another and translate
   differently in each.
3. **Name your variables.** `{count} items left` is translatable; `%s %s` is a guess.
4. **Do not assume two plural forms.** Never build a message as `1 item` / `n items` with a
   hand-rolled `if`; hand the count to the plural machinery and let each locale declare its
   own forms.
5. **Leave room to expand.** Translations commonly run 30–50% longer than a terse source
   string. A label that only fits at its exact source length is a layout bug waiting for the
   second locale.
6. **Keep markup out of the middle of sentences.** Split the link or the bold run into its
   own string, or pass it as a placeholder — do not force translators to reorder around
   embedded tags.
7. **Ship context with the string.** Where the string appears, what surface, what the
   variables hold, and the character budget. A translator cannot see your screen.
8. **Flag the untranslatable deliberately.** Puns, idioms, rhymes and culture-specific
   references do not survive. Either avoid them in strings meant to travel, or mark them as
   "re-create the effect, do not translate" and accept a different sentence per locale.
9. **Never put UI text inside an image.**
10. **Do not hard-code formats.** Dates, times, numbers, currency, names and address order
    all vary; let the locale layer format them.

If the `i18n-conventions` skill is installed, follow it for the mechanics — catalogue
layout, key naming, plural rules, extraction and fallbacks; this section only governs how
the source string is *written*. If the `ru-ui-strings` skill is installed, follow it for
Russian plural and gendered forms; if `ru-en-tone-transfer` is installed, use it when the
same message has to exist in both languages with the same intent.

## Honesty

This skill governs whether a string does its job, not whether its content is true. Any text
that states what the product did, produced, verified or knows about the reader is subject
to a stricter bar: no invented facts, no implied verification that did not happen, no
authority the product does not have. If the `writing-honesty-gates` skill is installed,
apply it to those strings; otherwise treat "do not invent facts, metrics, claims,
guarantees or authority signals" as hard, and escalate anything you cannot verify rather
than writing around it.

## Review checklist

Run these eight questions against every string under review:

1. What is the job of this string?
2. Who is reading it, and in what state?
3. What does the reader already know from the surrounding UI?
4. What action does this enable, prevent, or invite?
5. Can a word be removed without losing meaning?
6. Can the whole string be removed without hurting comprehension?
7. Is the text making a claim that needs evidence?
8. Is a local product voice guide available, and does the text follow it?

Two more when the product ships in more than one language:

9. Will this sentence survive translation as one unit, with its variables named?
10. Does the layout still hold if the translation is half again as long?

## Output guidance

**For drafting tasks:** return the text first. Keep rationale short unless the user asks
for a review. Where a surface has a real choice to make, give two or three options in one
line each with the difference named ("shorter, drops the reason"), not a paragraph of
commentary per option.

**For review tasks:** list the replacement and the reason. Prefer precise failure modes —
name the row from the tables above — over broad taste judgments. "Restates the heading" is
a finding; "feels a bit off" is not.

**Always say what you did not do:** strings you could not judge without seeing the surface,
facts you had to leave as placeholders, slots you think should be deleted but did not
delete, and any conflict between the job and the local voice guide.

### Definition of done

- [ ] The surface is named for every string produced or reviewed.
- [ ] The job sentence exists for every non-trivial string.
- [ ] Nothing was written purely to fill a slot, a character count or a layout.
- [ ] The cut pass ran as its own pass, and at least considered deleting each string.
- [ ] Per-surface requirements hold — buttons 1–3 words, errors calm and actionable, empty
      states naming what is missing and what creates it.
- [ ] No invented facts, metrics, claims or authority signals.
- [ ] One term per concept, consistent across the surfaces touched.
- [ ] Strings are whole sentences with named variables, safe to translate.
- [ ] The local voice guide was applied last, or its absence was stated.
- [ ] Conflicts between the job and the voice guide were reported, not silently resolved.

## Project delta

The consuming repo supplies:

- **The voice guide** — personality, humour level, register, address form, punctuation and
  capitalisation rules, emoji policy — as a local skill applied after Phase 6. If none
  exists, this skill defaults to plain neutral prose and says so.
- **Vocabulary and banned words** — the term for each domain concept, the words that are
  forbidden, and the product-name usage rules.
- **The surface inventory and budgets** — which surfaces exist in this product and the
  character or pixel budget for each.
- **The string catalogue** — where user-facing text lives, the key convention, and whether
  a string may be written inline at all.
- **Locales** — the current set, the source language, and whether new strings must be
  translation-ready on the first commit or later.
- **Regulated or legally reviewed text** — consent, billing, safety and compliance strings
  that must not be rewritten without the named reviewer.
- **The reviewer** — who signs off on user-facing text, and at which point in the change
  process.
