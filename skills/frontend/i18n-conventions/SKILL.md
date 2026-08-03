---
name: i18n-conventions
description: Internationalisation that survives the second locale — one catalogue per locale with flat dot-delimited keys, key-set parity enforced at compile time so a missing translation is a build failure instead of a silent fallback to the wrong language, CLDR plural categories resolved per locale (one/few/many, never an `n === 1` ternary), placeholder interpolation instead of string concatenation, a glossary so one concept is always one word, an explicit do-not-localize list (wire enums, ids, route paths, brand tokens), a string-expansion budget for layout, and flagging untranslated upstream text rather than faking it. Use when the user says "add a second language", "translate the UI", "i18n", "l10n", "localize this screen", "add Russian", "plural forms", "this string is hardcoded", "missing translation key", "language switcher", "why is this screen half English", or when adding any user-facing string to an app that ships more than one language.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Internationalisation conventions

The first locale is free — you write strings and they render. The cost lands on the second
one, and it lands as *silence*: a missing key falls back, a two-branch plural reads wrong,
a concatenated sentence puts the verb in the wrong place, and none of it fails a test.
This skill is the discipline that makes those failures loud.

Items marked `[!]` caused a real production incident when missed. They are not style
preferences.

## Scope

This skill defines only: **how translatable strings are stored and addressed, how catalogue
parity is enforced, how plural categories are resolved, how values are interpolated, how
terminology is kept consistent, what must not be translated, how layout absorbs string
expansion, and what to do with text that arrives already-written in the wrong language.**

It does not define visual design, typography or component structure — if a
`design-system-authoring` skill is installed, follow it for that layer. It does not define
the grammar of any particular language: Russian is used throughout as the worked example
because it is the canonical hard case (three integer plural categories, heavy case
inflection). If a `ru-ui-strings` skill is installed, follow it for Russian-specific wording,
gender and case rules; this skill only defines the machinery those rules live in.

## 1. Never hardcode a user-facing string

Every string a human can read goes through the translation layer. "User-facing" is wider
than it first looks:

| Counts as user-facing | Does not |
|---|---|
| Rendered text, headings, button and tab labels | Log lines and error messages sent to a log sink |
| Input placeholders, helper text, validation messages | Analytics event names and properties |
| Accessibility labels and hints (screen-reader-only text is still text) | Wire-format enumeration values |
| Status, toast and progress messages, including transient ones | Storage keys, route paths, test ids |
| Empty states, error-boundary copy, "not found" bodies | Developer-only diagnostics behind a debug flag |
| Notification titles and bodies, share-sheet text | Comments and identifiers in code |

Two call paths, and the difference matters:

- **Reactive**, inside components — a hook bound to the active locale (`t(...)`). Anything
  rendered through it re-translates the moment the user switches language.
- **Imperative**, in non-component code — async handlers, state providers, route
  containers — through a module-level accessor (`tt(...)`) reading a mirror of the active
  locale that the provider keeps in sync. Strings already produced this way do **not**
  re-translate on a live switch. That is acceptable for transient status text and wrong for
  persistent UI: if the string will still be on screen a minute later, render it through the
  reactive path.

Enforcement: a lint rule banning string literals in text positions, or failing that a CI
grep. Review catches the rest — but only if the reviewer knows to look, so put it in the
review checklist rather than in someone's memory.

## 2. One catalogue per locale, flat and dot-keyed

```
i18n/
├── translate.ts        # lookup, fallback chain, interpolation, the parity guard
├── plural.ts           # locale list, default locale, CLDR category resolution
└── locales/
    ├── en.ts           # key-set source of truth
    └── ru.ts           # must cover every key en defines
```

| Rule | Why |
|---|---|
| A catalogue is a **flat** map of dot-delimited keys to strings, not a nested object tree | one grep finds a key; a nested tree makes parity checking a recursive diff and lets a whole subtree go missing quietly |
| Key shape `<area>.<element>`, e.g. `profile.saveError`, `groups.nameLabel` | the key names where the string lives, so an untranslated screen is obvious from the key list |
| Status/flash messages get their own segment: `<area>.msg.<event>` | separates persistent UI from transient text, which have different re-render rules (§1) |
| Count-sensitive entries are stored suffixed — `<base>.one`, `<base>.few`, `<base>.many`, `<base>.other` — and callers pass the **base** key plus a count | the call site never knows which category applies; only the resolver does |
| Group keys by screen with comment banners, in the same order in every catalogue | makes a side-by-side diff of two catalogues readable |
| One string per key — never assemble a sentence from two keys | word order is a property of the language, not of your layout |

Do not key by English text (`t("Save changes")`). It looks convenient and then someone
edits the English copy, every other locale silently detaches, and the fallback ships.

## 3. Parity enforced at compile time

`[!]` **A missing key that resolves through a runtime fallback silently ships the wrong
language.** The screen renders, nothing throws, no test fails, and a user in the default
locale reads a sentence in the fallback language. This is the single most expensive i18n
defect because the only detector is a user noticing. A missing key must fail the **build**.

In a typed language, the guard is four lines and needs no dependency:

```ts
import { en } from "./locales/en";
import { ru } from "./locales/ru";

// The source-of-truth locale defines the key set.
export type CatalogKey = keyof typeof en;

// Compile-time guard: `ru` must define every key `en` does. A gap surfaces here as a
// type error during `tsc --noEmit`, never as a runtime fallback. Extra keys — the
// `.few` / `.many` variants Russian needs — are allowed on top.
const _ruCoversEn: Record<CatalogKey, string> = ru;
void _ruCoversEn;
```

Type the *base* keys too, so the call site can pass a base key and still be checked:

```ts
type PluralSuffix = "one" | "few" | "many" | "other";
type PluralBaseOf<K> = K extends `${infer Base}.${PluralSuffix}` ? Base : never;

export type PluralKey = PluralBaseOf<CatalogKey>;      // "group.members", …
export type TranslationKey = CatalogKey | PluralKey;   // what `t()` accepts
```

Add one catalogue line per locale, get one type error per missing translation, at the same
moment as every other type error. Rules:

- The guard runs in the **same command CI already gates on** (`typecheck`, `build`). A check
  that lives in a script nobody runs is not a guard.
- Untyped stack? Replace the type assertion with a test that diffs key sets in both
  directions and fails on any asymmetry other than the permitted extra plural suffixes. Same
  contract, different mechanism.
- Keep the runtime fallback chain anyway — as a crash guard, not as a policy. Last resort is
  to render **the key itself**: it never throws, and a screen showing `groups.nameLabel` is a
  bug report writing itself. Never render an empty string; the gap becomes invisible.

## 4. Key-set source of truth ≠ default display locale

These are two different decisions and they are allowed to disagree.

| | Key-set source of truth | Default display locale |
|---|---|---|
| Decides | which keys must exist everywhere; what the parity guard is derived from; which catalogue the runtime fallback reads | what a first-run user sees before choosing anything |
| Chosen by | engineering | product / launch market |
| Changing it | re-points the guard and the fallback — rare, deliberate | a product decision, cheap |

Pick the source of truth as **the locale with the fewest plural categories** — in practice
English. The superset only works in one direction: a two-category catalogue can be covered by
a three-category one (`.one`/`.other` plus `.few`/`.many` on top), but if the source locale
demanded `.few` and `.many`, every two-category locale would have to carry duplicate dead
entries to satisfy the guard. A secondary reason: the fallback catalogue is the one every
contributor can proofread.

The default *display* locale is whatever the market speaks. If the launch market is Russian,
ship Russian by default and English opt-in — while English remains the key set. That is the
common, correct configuration, and it is precisely why §3 is marked `[!]`: with the fallback
in a different language from the default, one missing key produces a screen that is *mostly*
Russian with an English sentence in the middle.

- Persist the user's choice under a namespaced storage key (`<app>:locale`) and read it
  before first paint to avoid a flash of the wrong language.
- If the default is a deliberate product decision, do **not** auto-detect the device locale —
  auto-detection quietly overrides the decision. If you do detect, map unsupported locales to
  the default and always leave a manual override in settings.
- Validate the persisted value through a type guard before use; a stale or hand-edited value
  must fall back to the default, not index into an undefined catalogue.

## 5. Plurals are per-language, and a ternary is a bug

`[!]` **A two-branch plural is wrong the moment a language with more than two categories is
added.** It does not fail loudly; it produces grammatically broken text at specific counts
that no one thinks to test — a Russian user sees the equivalent of "5 member" on any screen
whose count happens to land in the `many` category.

```ts
// WRONG — encodes English grammar at the call site.
<Text>{count === 1 ? "1 member" : `${count} members`}</Text>
<Text>{t("group.member") + (count === 1 ? "" : "s")}</Text>

// RIGHT — the call site passes a number; the catalogue owns the grammar.
<Text>{t("group.members", { count })}</Text>
```

The catalogue stores every category the locale needs, and the resolver appends the one it
picked to the base key:

```ts
// en.ts — two categories
"group.members.one":   "{{count}} member",
"group.members.other": "{{count}} members",
```

```ts
// ru.ts — three integer categories, plus .other for non-integers
"group.members.one":   "{{count}} участник",
"group.members.few":   "{{count}} участника",
"group.members.many":  "{{count}} участников",
"group.members.other": "{{count}} участника",
```

Resolution, following the Unicode CLDR plural rules:

```ts
export type PluralCategory = "one" | "few" | "many" | "other";

function englishCategory(n: number): PluralCategory {
  return n === 1 ? "one" : "other";
}

// Russian integer rule (CLDR):
//   one  — n % 10 == 1 and n % 100 != 11             (1, 21, 31, …)
//   few  — n % 10 in 2..4 and n % 100 not in 12..14  (2, 3, 4, 22, …)
//   many — everything else                           (0, 5..20, 25, …)
function russianCategory(n: number): PluralCategory {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return "one";
  if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return "few";
  return "many";
}

export function pluralCategory(locale: Locale, count: number): PluralCategory {
  const n = Math.abs(Math.trunc(count)); // categories below are defined on integers
  return locale === "ru" ? russianCategory(n) : englishCategory(n);
}
```

Worked example — the mod-10/mod-100 arithmetic and the 11–14 exception, in Russian:

| count | n % 10 | n % 100 | category | rendered (example) |
|---|---|---|---|---|
| 1 | 1 | 1 | one | «1 участник» |
| 2 | 2 | 2 | few | «2 участника» |
| 5 | 5 | 5 | many | «5 участников» |
| 0 | 0 | 0 | many | «0 участников» |
| 11 | 1 | 11 | **many** | «11 участников» — the mod-100 exception; a naive mod-10 rule says `one` |
| 12 | 2 | 12 | **many** | «12 участников» — 12–14 excluded from `few` |
| 21 | 1 | 21 | one | «21 участник» |
| 22 | 2 | 22 | few | «22 участника» |
| 111 | 1 | 11 | many | «111 участников» — the exception is on mod 100, so it recurs every century |

Rules that fall out of this:

- **Test 1, 2, 5, 11, 21 and 0 at minimum.** A plural bug that only appears at 11 survives
  every hand-check that stops at 3.
- **`.other` must exist for every plural base in every locale.** It is the resolver's second
  candidate after the exact category and covers fractions ("2.5 hours"), which use `other`
  in Russian even though no integer does.
- The lookup order is `<base>.<category>` → `<base>.other` → `<base>` → next locale in the
  fallback chain → the key itself. Each step is a degradation, and each one is visible.
- Zero is a **language** question, not a product one: Russian puts 0 in `many`. If the
  product wants "No members" instead of "0 members", that is a separate key chosen by the
  call site, not a fourth branch inside the plural.
- A platform `Intl.PluralRules` implementation is a fine substitute for the hand-rolled
  function *where the runtime ships full locale data*. **Verify** before relying on it: some
  mobile and embedded JS engines are built without complete ICU data and quietly answer
  `other` for everything, which is the §5 bug with extra steps.
- Ordinals ("2nd") and ranges ("2–4 items") use different category sets from cardinals.
  Neither is covered here; if you need them, reach for a full ICU MessageFormat
  implementation rather than extending this table.

## 6. Interpolation, never concatenation

Values are injected by named placeholder, passed as a params object:

```ts
"home.greetingWithPlace": "Good morning, {{name}} · {{place}}",
```

```ts
const INTERPOLATION = /\{\{(\w+)\}\}/g;

function interpolate(template: string, params?: TranslateParams): string {
  if (!params) return template;
  return template.replace(INTERPOLATION, (_full, name: string) => {
    const value = params[name];
    // Leave the placeholder visible rather than printing "undefined".
    return value === undefined || value === null ? `{{${name}}}` : String(value);
  });
}
```

- **Never build a sentence by concatenating translated fragments.** Word order, and in
  inflecting languages the *form* of each word, depend on the whole sentence. `t("deleted") +
  " " + itemName` is a bug in every language that is not English.
- One key per complete sentence, placeholders for the variable parts. If two sentences differ
  only in one word, they are still two keys.
- Placeholders carry **data** — names, counts, dates, place labels — not translated fragments.
  Interpolating a translated noun into a translated sentence forces the noun into a fixed
  grammatical case that will be wrong in some sentences.
- Keep markup out of catalogue values. If a string needs a bold span or a link, split it at
  the placeholder and let the component render the parts.
- Numbers, dates, currency and lists go through the platform's locale-aware formatter, not
  through a hand-assembled string. A raw `String(n)` in a placeholder is fine for small
  counts and wrong for anything with a thousands separator.
- A missing param renders as the literal placeholder. That is deliberate: `{{name}}` on
  screen is diagnosable, `undefined` is embarrassing, and an empty string is invisible.

## 7. A glossary, so one concept is always one word

Two contributors will translate the same concept two ways in the same week. Write the
mapping down at the top of the catalogue file (or in a `GLOSSARY.md` the catalogue links to)
and treat it as binding:

| Concept (source) | Term (target) — example | Applies to |
|---|---|---|
| member | «участник» | list labels, counts, detail screens |
| group | «группа» | tab title, headings, empty states |
| invite | «приглашение» | notifications, action sheets, confirmations |

(Illustrative rows only — a real glossary lists the consuming product's own nouns.)

- The product's own concept nouns are the ones that drift most — the tab name, the object
  the app is about. Fix those first.
- The glossary is a review artefact: a new string using an off-glossary synonym is a review
  comment, not a matter of taste.
- **Enumerations render through the catalogue, never as raw values.** Give them their own
  namespace — `enums.<kind>.<value>` — and a small typed helper that composes the key, so a
  new enum member missing a label is caught by the same parity guard as everything else.
  Never `capitalize(value)` a wire value into the UI.

## 8. The do-not-localize list

| Never translate | Because |
|---|---|
| Enumeration values on the wire, and any field sent **to** a service | the receiver parses them; a localized value is a broken payload |
| Identifiers, slugs, keys, tokens | they are addresses, not text |
| Route paths and deep-link segments | localized routes fork the URL space and break saved links |
| Storage keys, feature-flag names, test ids | they must be stable across locales and versions |
| Brand tokens and the product name | the name is the same word everywhere |
| Log messages, metrics labels, analytics event names | they are read by engineers and by machines, and localized logs are ungreppable |
| Error codes (the code, not its human message) | the code routes handling; only its display string is translated |

The rule underneath: **if a string crosses a process boundary as data, it is not UI text.**
The same concept often needs both — a stable code on the wire and a `errors.<code>` catalogue
entry for display. Keeping them separate is the whole point.

## 9. String expansion and layout

Translation changes the length of every string, and short strings move most in relative
terms. Budget for it in the layout rather than discovering it in a screenshot.

| Source length (English) | Plan for | Notes |
|---|---|---|
| ≤ 10 chars (buttons, tabs) | +100% | the worst case by far — a 4-character label can triple |
| 11–30 chars (labels, titles) | +50% | |
| 31–70 chars (sentences) | +30% | |
| > 70 chars (paragraphs) | +20% | |

- Never size a control to fit the source-language string. Let labels wrap to two lines, or
  give the container a minimum and let it grow.
- Never truncate the only label on a control. Truncating a compound label mid-word — say
  «Настройки уведомлений» clipped to «Настройки увед…» — produces text that is not merely
  ugly but unreadable.
- Never compute layout from character counts, and never decide behaviour on
  `text.length > n`.
- Uppercase transforms are locale-dependent. Russian uppercases cleanly; other languages do
  not (case-mapping surprises exist in German and Turkish). If a design calls for caps, apply
  it as a *style*, and check the result in every shipped locale.
- Check glyph coverage: the fonts and icon fallbacks must actually contain the target
  script's characters at every weight the design uses.
- Review the longest locale, not the source one — that is where clipping shows up.

## 10. Untranslated content from elsewhere gets flagged, not faked

Text produced by a service, an external dataset or a model arrives in whatever language that
producer speaks. Three legitimate options, in order of preference:

1. **Localize at the source** — the service returns a key plus params, and the client
   translates. The right answer for anything the service composes.
2. **Localize by stable id on the client** — the payload carries an id, the client catalogue
   holds `<namespace>.name.<id>`. Works for a small, slow-moving set (a curated catalogue of
   place or category names); does not scale to user-generated content.
3. **Display as received and record the gap** — in the project's agent guide or known-issues
   document, naming the surface and what it would take to fix.

What is forbidden: machine-translating at render time to hide the gap, inventing a
translation for a term with no glossary entry, or leaving the gap undocumented so the next
contributor rediscovers it. **Flag it rather than faking it** — an honest English sentence in
a Russian screen is a known defect; a fabricated translation is an unknown one. If a
`writing-honesty-gates` or `llm-pipeline-rules` skill is installed, the same rule about not
inventing content applies here.

User-generated content is never translated silently either. If it is translated at all, the
UI says so and offers the original.

## 11. Adding a string — the procedure

1. **Pick the key** — `<area>.<element>`, or `<area>.msg.<event>` for transient text. Reuse
   an existing key only when it is genuinely the same sentence in the same role.
2. **Add it to the source-of-truth catalogue**, in the right comment-banner group.
3. **Add it to every other catalogue**, with *all* the plural categories that locale needs
   when the string is count-sensitive.
4. **Check the glossary** for every domain noun in the string; add the term if it is new.
5. **Call it** through the reactive hook in components, the imperative accessor elsewhere,
   passing `{ count }` and named params. No concatenation, no ternary.
6. **Run the parity check** (`typecheck` / `build`) and fix the type errors it raises.
7. **Look at it in the longest locale**, at the plural boundaries that matter (1, 2, 5, 11,
   21, 0), on the narrowest supported screen.

## 12. Definition of done

- [ ] No new user-facing string literal anywhere in the diff — including accessibility
      labels, placeholders, toasts and empty states.
- [ ] Every new key exists in **every** catalogue; the parity check passes in the same
      command CI runs.
- [ ] Count-sensitive strings use base key + count, with every category the locale defines
      and an `.other` entry; no `n === 1` ternary and no suffix concatenation.
- [ ] Plurals eyeballed at 1, 2, 5, 11, 21 and 0.
- [ ] All variable parts interpolated by named placeholder; no sentence assembled from
      fragments; numbers and dates through a locale-aware formatter.
- [ ] Domain nouns match the glossary; new terms added to it.
- [ ] Nothing on the do-not-localize list was translated; no localized value sent to a
      service.
- [ ] Layout checked in the longest locale on the narrowest screen — no clipping, no
      truncated single label, no character-count logic.
- [ ] Any text still arriving untranslated from elsewhere is documented, not faked.
- [ ] Locale switch exercised end to end: persisted choice survives restart, reactive UI
      re-renders, no unresolved keys on screen.

## Choosing a library, or hand-rolling

| Hand-rolled layer fits when | Take a full i18n library when |
|---|---|
| Two or three locales whose plural rules you can state | Many locales, or locales you cannot proofread |
| Engineers write the strings; no translation vendor in the loop | Translators need import/export, TMS integration, context screenshots |
| No gender/select forms, no ordinals, no ranges | You need full ICU MessageFormat: select, ordinals, nested plurals |
| The dependency has a real cost — e.g. it pulls in a native module, and the delivery model ships JavaScript updates without a store rebuild | RTL layout, per-locale asset bundles, lazy catalogue loading |

A hand-rolled layer is a handful of small files: catalogues, plural categories, a lookup with
a fallback chain, a provider, and the compile-time guard. That guard is most of the safety a
library would have given you.

Non-negotiable either way: parity checked at build time, plural categories owned by the
locale and not by the call site, and no sentence built by concatenation.

## Project delta

The consuming repo supplies:

- The shipped locale set, which locale is the **key-set source of truth**, and which is the
  **default display locale** — plus whether device-locale detection is on.
- Where the catalogues live, the file layout, and the comment-banner grouping order.
- The exact command that runs the parity check, and the CI job that gates on it.
- The names of the reactive and imperative accessors (`t` / `tt` / `ta` or otherwise) and the
  rule for which call sites use which.
- The interpolation placeholder syntax if it is not `{{name}}`.
- The storage key holding the persisted locale, and where it is read before first paint.
- The glossary: the product's concept nouns and their agreed term per locale.
- The project's do-not-localize additions — wire enums, id namespaces, brand tokens.
- Which surfaces still receive text from elsewhere untranslated, and where that gap is
  recorded.
- The lint rule or grep that fails a build on a hardcoded user-facing string.
