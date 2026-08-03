---
name: design-system-authoring
description: Author and maintain a design system that code actually follows — token files as the single source of truth, component specs that prescribe intent and usage constraints instead of props, and a thin loader skill fronting a large asset directory — then audit the built app for drift against it. Use when asked to "create a design system", "write design tokens", "document our components", "write a component spec", "set up a design skill for this brand", "make the app match the mockups", "audit the UI for design drift", "find hardcoded colours", "why doesn't the build look like the prototype", "review our design consistency", or when adding a component to an existing system, reviewing UI code against it, or reporting where a shipped build has quietly departed from its intended look.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Design-system authoring

How to write a design system that survives contact with a codebase, and how to prove
whether the codebase is still following it.

**This skill defines only three things**: (1) how token files are structured and
referenced, (2) how a component spec is written — intent and usage constraints, not
props, and (3) the drift-audit procedure that compares a running build against the
system. It does **not** define visual taste (which colours, which typeface, which
mood — that is the project's own brand decision), component implementation, styling
libraries, or test tooling. Where a project already has a design system, extend it in
its own vocabulary rather than renaming things.

`[!]` below marks two rules that were broken in a real shipped build and found only by
the audit in section 5 — not hypotheses.

---

## 1. The five artifacts

| Artifact | Typical location | Owns | Never contains |
|---|---|---|---|
| Token files | `design-system/tokens/*` | every literal value in the product | component logic |
| Component specs | `design-system/<Component>.md` | intent, meaning of variants, usage constraints | prop tables, types |
| Type declarations | beside the implementation (`.d.ts`) | prop names, shapes, defaults | rationale |
| Visual ground truth | `design-system/<name>.html` (a static prototype) | what the screens actually look like | anything unreachable from the tokens |
| Drift audit | `docs/design-review/` | how far the build has moved, and when it was measured | fixes applied in place |

The loader skill (section 4) is the index over all five. Keep the artifacts separate:
merging the spec into the `.d.ts` produces a system that documents props and forgets
why, which is the failure this skill exists to prevent.

## 2. Tokens: the single source of truth

### 2.1 Families

| Family | Must define | Naming | Typical failure |
|---|---|---|---|
| Colour | page/surface, ink, borders, one action accent, positive, caution, map/media fills, tints for each accent, plus text-on-tint colours | role names (`--color-surface-card`), not value names (`--color-beige`) | a second "accent" appears and the CTA stops being findable |
| Type | family per role (display / UI / mono), the full size scale with **named steps**, the weight ladder, tracking and leading | `--font-size-title`, `--font-weight-strong` | sizes named by px value, so the scale cannot change |
| Spacing | one arithmetic ramp (`4 8 12 16 20 24`) plus named layout constants (screen gutter, form gutter) | `--space-1…6` | ad-hoc `13px` gaps that no ramp explains |
| Radius | one entry per shape class (pill, card, card-lg, sheet, input, chip, tile) | shape names | components inline `borderRadius: 14` |
| Shadow | one per elevation *purpose* (card lift, floating control, primary CTA glow, sheet, toast) | purpose names | grey/black shadows in a warm palette |
| Layout | control border width, minimum hit target, hit slop, breakpoints | — | a 32px tap target ships |

Rules:

1. **Code references tokens, never literals.** One grep for `#[0-9a-fA-F]{3,8}`,
   `borderRadius: <number>` and raw `px` font sizes outside the token module is the
   cheapest design-system test that exists. Run it in CI.
2. **One action accent.** If everything is emphatic, the primary action is invisible.
   Every additional accent must earn a documented role ("positive/match", "caution").
3. **Semantic aliases are optional, but must exist on both sides or neither.** A CSS
   layer of `--surface-*` / `--text-*` / `--accent-*` aliases that the app's token module
   does not mirror is structural drift: both sides describe colour in a different
   vocabulary and diverge the moment either is edited.
4. **Shadows carry the palette.** Tint every shadow with the ink or the accent it sits
   under. A neutral-black shadow under a warm palette reads as dirt.
5. **Never edit a value in one platform's copy.** Change the token source, then
   propagate. Cross-platform copies (`tokens.css` and `tokens.ts`) are generated or
   hand-mirrored — either way the direction of truth is one-way and written down.
6. **`[!]` Declaring a font family is not delivering it.** A web stylesheet `@import`
   does not apply on a native runtime, and a native `fontFamily: "<Face>"` on a web
   target silently falls back to a system face. Both look "fine" in review and both mean
   the entire product is rendering in the wrong typeface. *Verify per target*: the font
   is bundled/loaded, and a screenshot shows the real face — not the declaration.
7. **`[!]` Check contrast on the actual pairs you ship**, not just ink-on-page. Warm
   secondary text on a tinted surface is the usual offender: it can measure below 3:1
   where AA needs 4.5:1 for normal text. Record the measured ratio for every
   text-on-surface and text-on-tint pair in the token docs; fix by darkening the *role*,
   not by patching one screen.
8. **A token is not a place to park one-off values.** A colour used by exactly one
   component that will never be reused stays a documented component constant, or gets
   promoted deliberately with a role name.

### 2.2 Structure

```
design-system/
  styles.css            # entry point; imports everything under tokens/
  tokens/
    fonts.css           # face declarations + delivery mechanism per target
    colors.css          # base palette, then the semantic alias layer
    typography.css      # families, scale, weights, tracking, leading
    layout.css          # spacing ramp, radii, shadows, hit targets
```

The app's own token module (`src/design/tokens.*`) mirrors this file-for-file. If a
token exists on both sides, its **value must be identical**; if it exists on one side
only, that is a decision that belongs in the audit, not a silent divergence.

## 3. Component specs: prescribe intent, not props

A spec that documents props is stale the day someone renames one, and it duplicates the
type declaration next to it. A spec that documents **when, how many, where, and what
this is not for** survives renames, framework migrations and full re-skins, because it
encodes the judgement that no signature can express. Write specs for the second kind of
knowledge and let `.d.ts` carry the first.

| Goes in the spec (prose) | Goes in the type declaration |
|---|---|
| What the component *is* and where it sits in the hierarchy | prop names, types, defaults |
| What each variant/tone **means** semantically | the variant union |
| Cardinality limits ("at most one per screen") | — |
| Placement rules ("pinned at the bottom", "inside cards only") | — |
| Who owns the transform (the component uppercases; pass sentence case) | — |
| Who owns the string (caller passes localized text; component builds none) | — |
| Explicit prohibitions: what it is **not** for, and what it must never render as | — |

### 3.1 Format

```markdown
---
category: Actions | Display | Inputs | Type | Navigation | Brand
---
<Paragraph 1 — identity.> What it is, its default state, the one sentence that
distinguishes it from its nearest sibling.

<Paragraph 2 — meaning.> Each variant/tone and what it communicates. Colour and casing
are semantics here, not styling.

<Paragraph 3 — constraints and prohibitions.> Cardinality, placement, sizing rules,
ownership of transforms and strings, and the explicit "never" clauses.
```

Three short paragraphs. If a spec needs a fourth, the component is doing two jobs.

### 3.2 Constraint kinds worth stating

| Kind | Example clause (generic) |
|---|---|
| Cardinality | "at most one `primary` per screen"; "mark at most one column `accent`" |
| Placement | "usually pinned at the bottom"; "for secondary groupings inside an already-carded area" |
| Sizing by context | "`lg` for the pinned action, `md` inside cards, `sm` in dense rows" |
| Reservation | "reserve `positive` for genuinely good news — not for every non-error state" |
| Transform ownership | "the component uppercases `children`, so pass sentence case in" |
| String ownership | "`label` renders as-is and must already be localized — the component builds no strings" |
| Derivation | "pull the placeholder colours from the token export rather than inventing them" |
| Prohibition | "never a percent pill, never a ring"; "never box these — the hairline rule *is* the container"; "no fill and no checkmark" |
| Substitution ban | "there is no icon font and no logo asset — do not invent one" |

The prohibition line is the highest-value sentence in any spec. It is the only place a
future implementer learns that the flat circle they were about to build is the exact
thing the system rejected.

### 3.3 Worked example — `ActionPill` (invented, neutral)

```markdown
---
category: Actions
---
The single tappable-action primitive: a pill, `size` sm / md / lg. `primary` is THE call
to action — at most one per screen, normally pinned at the bottom of the scroll.
`secondary` (1.5px outline) and `quiet` (bare label) are the steps down; `danger` is
reserved for destructive confirmation and never appears twice on one screen.

`primary` sets its label in the display face, uppercase, with wide tracking — that
casing is the action signature, so pass a label that survives uppercasing ("START", not
a sentence). `secondary` and `quiet` use the UI face one step smaller, which is how the
eye ranks them before reading them. The brand mark belongs only on the one action the
product is named for; everywhere else it is decoration.

Use `size="lg"` only for the pinned bottom action, `md` inside cards, `sm` in dense rows.
ActionPill is **not** a navigation control — a row that opens a detail screen is a
pressable row with a `›` affordance — and **not** a filter, which is `SelectChip`. Never
place two solid fills side by side; pair a primary with a secondary.
```

### 3.4 Worked example — `FigureRow` (invented, neutral)

```markdown
---
category: Display
---
The signature statistic treatment: 2–3 columns of large display-face numerals with caps
micro-labels beneath, separated by 1px hairlines.

Numbers are the hero: pass a short `value` and a caps `label` ("12.4" / "KM THIS WEEK").
`onDark` inverts it for dark header blocks, where the dividers go translucent and one
numeral may take the on-dark accent.

Mark at most one column `accent`. **Never box these in a card** — the hairline rule *is*
the container, and wrapping it in a surface destroys the pattern it exists to create.
```

Note what neither example contains: a prop table, a hex value, or a pixel that is not a
rule. Both are re-implementable in any framework, and both would still be correct after
a full re-skin.

## 4. The loader skill: a thin stub over a large asset directory

A design system is megabytes of CSS, prototypes, specimens and component sources. Do not
inline it into a skill body, and do not make the agent guess which of forty files is
authoritative. Write a **stub of roughly 20–40 lines** whose only job is orientation.

The stub contains, in order:

1. **Frontmatter** — `name` and a `description` naming the product surface and the words
   a user would say. No tool-specific keys; the stub must load in any agent.
2. **A single instruction to read the asset `README.md` and explore the directory.**
3. **Key facts in one dense paragraph** — the mood in one clause, the palette by role
   (not a table), the type pairing, the signature patterns, and the explicit *nots*
   ("no gradients, no icon font, no emoji, no cool greys"). This paragraph is what a
   fast agent will act on without opening anything else, so it must be correct.
4. **Where things live** — one line each for tokens, component specs, the visual ground
   truth file, and the flow/copy ground truth file if they differ. Name which file wins
   when two disagree, and say which is superseded.
5. **Product rules baked into the UI** — constraints that explain otherwise-arbitrary
   design decisions (for example: no free-text input, so all coordination is buttons).
6. **The branch** — the one paragraph that changes behaviour:
   - *Throwaway artifacts* (mocks, slides, prototypes): copy assets out and produce
     self-contained static HTML the user can open. Never wire them to the app.
   - *Production code*: copy the tokens into the app's token module and follow the rules
     here; do not restyle components ad hoc.
7. **The no-guidance fallback** — if invoked bare, ask what to build, ask a few
   questions, then act as the designer.

```
skills/<brand>-design/
  SKILL.md              # the stub — 20–40 lines
  readme.md             # the real system: fundamentals, foundations, iconography, index
  tokens/               # the token files (section 2.2)
  components/<category>/<Name>.{jsx,d.ts,prompt.md}
  guidelines/*.html     # specimen cards: colour, type, radius/shadow, iconography
  <name>.html           # visual ground truth — the full hi-fi prototype
```

The `readme.md` carries an **INDEX** section listing every file with one line on what it
is authoritative for, plus a **Status** line stating honestly what is implemented and
what is still only drawn. Version the language itself (`v2 "<name>"`) and say what it
replaced and when — a system with two live visual languages and no labels is the most
expensive kind of drift.

## 5. The drift audit

Goal: a dated, reproducible statement of how far the built app has moved from the
system, ranked by impact, with each finding assigned a direction of fix. This is
**analysis, not repair** — never fix findings inside the audit pass.

### Phase 1 — Extract from code

Read the app's token module, every component, and every screen composition. Produce
three files under `docs/design-review/extraction/`:

| File | Contains |
|---|---|
| `token-drift.md` | every colour/type/spacing/radius/shadow token, app value vs system value, per-row match mark, and the role of each token |
| `component-inventory.md` | every component: one-line purpose, props, styling facts, and a per-component **Drift** bullet; then a cross-component drift summary |
| `screen-layouts.md` | top-to-bottom structure of every screen, shared chrome, states (loading / empty / error), and the copy patterns |

Mark each token row `✓` (exists both sides, same value), `app-only`, or `ds-only`. Then
separate the two kinds of divergence, because they need different responses:

- **Value drift** — the same token has different values on the two sides. Always a bug.
- **Structural drift** — a token or member exists on one side only. A decision to make:
  adopt it into the system, or delete it from the app. Say which.

### Phase 2 — Capture the running build

Screenshot the **real running UI**, not the prototype, at a fixed viewport (e.g.
390×844 for phone), in the app's primary locale, covering every screen and the states
that matter (empty, loading, error, active).

Getting a mobile-only build to render in a browser is usually the hard part, and it is
worth doing: a web target makes the whole audit repeatable. A native-only module (maps,
camera) will break web bundling — a platform-suffixed sibling file that renders a
stand-in is the standard fix and is safe to keep. A demo-data flag that bypasses the
backend is **not** safe to keep.

Every edit made to enable capture is listed in the audit's *Reproduce* section
with its disposition — **kept** (and why it is harmless) or **reverted** (and confirmed
unchanged). An audit that leaves a demo-mode short-circuit in the HTTP client is worse
than no audit.

### Phase 3 — Compare

Put the captured screens beside the system's ground-truth prototype, screen for screen.
Look for the patterns that recur in every audit:

| Pattern | What it looks like |
|---|---|
| Signature visual simplified | the system's distinctive element (a proportional ring, a hairline band, a derived placeholder) shipped as its flat, easy approximation |
| Systemic over-bolding | resting/inactive states set one or two weights above spec, so active and inactive stop being distinguishable |
| Missing state elevation | the specced shadow on active/positive controls absent because the app's token module never defined it |
| Renamed or retyped props | `attention` vs `featured`, `value` vs `on`, enum sizes vs numeric — the spec and the build stop being about the same component |
| Control sizing off-spec | chips, switches and segments a few px off, individually invisible, collectively "not the brand" |
| Default variant flip | the primitive defaults to the *quiet* variant, so screens quietly lose their emphasis ladder |
| Off-token literals | one near-miss accent hex and a couple of literal radii that dodge the token layer |
| Identity colour not derived | the same entity renders a different colour on two screens because colour is passed as data instead of hashed from the id |
| Signature rule broken wholesale | the system says "no icon font"; the app ships one. Usually fine-looking and always undocumented |
| Dead component shadowing the real one | a spec-compliant component exists in the tree while the framework renders a different, off-spec one — check what actually mounts |
| Unimplemented spec member | a documented variant or sibling component that was never built |

### Phase 4 — Rank and report

One bundle (`docs/design-review/`) with the extraction files, the screenshots, and a
readable summary. Lead with a **strengths** block: an audit that opens with eleven
problems gets read as hostile and ignored. Then findings, ranked by impact on the
experience, each in this shape:

```
<rank> · <one-line claim, not a category>            <severity>  <category>
<2–4 sentences of evidence: what the system says, what the build does, what it costs.>
<measurements where they exist: "measured 2.9:1 · AA needs 4.5:1">
Recommend: <the specific change, in the codebase or in the system, and where>
```

| Field | Values |
|---|---|
| Severity | `high` (brand or accessibility failure that ships to every user) · `medium` · `low` |
| Category | `adherence` · `accessibility` · `consistency` · `brand fidelity` · `maintainability` · `structure` |
| Direction | fix the **code**, fix the **system** (adopt what the build learned), or make it a **decision** and document it |

The third direction matters. When the build has diverged for a reason — extra accents
that the system never documented, a sanctioned icon-set substitution — the honest
finding is "make this a decision, not drift", and the fix lands in the design system.

Close with **Reproduce**: the exact commands and viewport used, the locale, and the
edit-disposition list from Phase 2. An audit nobody can re-run is a one-off opinion.

If the `ui-test-playwright` skill is installed, use it to automate the repeatable half
of this — token compliance, geometry assertions, visual regression — and keep this
skill's judgement work for what a test cannot assert.

## 6. Definition of done

Authoring:

- [ ] Every family in §2.1 has token entries with role-based names, in one source, with
      a one-way mirror to each platform's copy.
- [ ] A CI grep proves no colour hex, raw radius or raw font size outside the token module.
- [ ] Contrast measured and recorded for every text-on-surface and text-on-tint pair.
- [ ] Font delivery verified on **each** target by screenshot, not by declaration.
- [ ] Every component has a spec with identity, meaning, and at least one explicit
      "never" clause; props live in the type declaration, not the spec.
- [ ] The loader stub is under ~40 lines, names the authoritative files, states which
      are superseded, and branches between throwaway artifacts and production code.
- [ ] The asset `readme.md` has an INDEX and an honest Status line.

Auditing:

- [ ] Three extraction files exist and cover every token, component and screen.
- [ ] Value drift and structural drift are separated and counted.
- [ ] Screenshots are of the running build, at a stated viewport and locale.
- [ ] Findings are ranked, severity- and category-tagged, each with evidence and a
      direction of fix; strengths are stated first.
- [ ] Reproduce section lists commands and the disposition of every enabling edit.
- [ ] No fixes were applied during the audit.

## 7. Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Spec = prop table | Duplicates the types, goes stale on rename, encodes no judgement |
| System documented only in the prototype file | Nobody diffs an HTML file; rules that are only visible are not rules |
| Two live visual languages, neither labelled | Every new screen picks one at random |
| Tokens copied into the app and then edited there | Two sources of truth, drift compounding silently |
| "Design review" that fixes as it goes | The measurement is destroyed by the repair; nothing is reproducible |
| Findings without measurements | "Contrast looks low" is arguable; "2.9:1 against a 4.5:1 bar" is not |
| Accent inflation | A second and third accent make the primary action invisible |
| Enabling hacks left in the tree | The audit becomes the source of the next production incident |

## Project delta

The consuming project supplies:

- **The brand itself** — palette, typefaces, mood, casing rules, iconography policy and
  the signature patterns. This skill prescribes none of them.
- **Paths** — where the design system lives (`design-system/`, a skill asset directory,
  or a package), where the app's token module lives, and where audits are written.
- **Platform and viewport** — the targets to verify font delivery on, the capture
  viewport(s), and how the running build is booted for capture.
- **Component categories** — the category vocabulary used in spec frontmatter.
- **Locale** — the primary locale screenshots are taken in. If the `i18n-conventions`
  skill is installed, follow it for string ownership between component and caller;
  otherwise state the ownership rule in each spec.
- **The CI grep** — the exact allowlist of files permitted to contain literal values.
