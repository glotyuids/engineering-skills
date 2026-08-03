---
name: ui-test-playwright
description: Build, extend or run a Playwright (@playwright/test) end-to-end suite for a web app, and automate design review on top of it (token compliance, geometry rules, visual regression, on-demand vision audit). Use when the user says "add a Playwright test for X", "extend the e2e suite to cover Y", "write a spec for the new feature", "test this flow end-to-end", "set up Playwright in this repo", "cover the editor in e2e", "our e2e suite is flaky", "find design inconsistencies", "automate design review", "check for colour drift / spacing drift", "visual regression", or asks for new coverage on an existing suite. Also use for ad-hoc browser verification through a browser-automation MCP when no suite exists yet — but prefer adding a spec once one does.
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.0
---

# Playwright end-to-end suites and design-review automation

**Core rule: the committed `@playwright/test` suite is the source of truth. An interactive
browser — MCP-driven or headed — is for exploration and debugging only. Anything verified
in a browser and not committed as a spec will regress and nobody will notice.**

**A state-mutating spec that can reach a shared environment will eventually be run
against production.** Suites get copied into CI, aliased into `make test`, or run by a
contributor with a stale shell. A hard guard that refuses to execute mutating tags against
a shared base URL is what makes it acceptable to keep those specs committed at all. Losing
that guard is the single fastest way to get an e2e suite banned from a project.

This skill defines only the shape of a browser-driven e2e suite — layout, tagging,
fixtures, page objects, spec discipline, determinism — plus the four-layer design
conformance programme built on the same runner. It does not define unit tests, component
tests, API or contract tests, or load testing. Every code shape below is a **labelled
illustration with placeholder names**, never a real product surface. If the
`integration-testing` skill is installed, its gate, credential and cleanup rules govern any
run against a shared deployed environment; this skill covers the browser layer's own
mechanics.

If the repo already has an e2e directory, **extend it**. Do not start a parallel suite.

## 1. Decisions to lock in before the first spec

Put all five to the user in **one** round, not one at a time. Each one is expensive to
change once specs exist.

| Decision | Options | Default | Why it is hard to change later |
|---|---|---|---|
| **Runner** | `@playwright/test`; an interactive MCP browser | `@playwright/test` | An MCP browser drives one tab interactively — fine for exploration, useless in CI. Nothing else in this skill applies to it |
| **Target env** | local dev; local production build; ephemeral; shared staging; dedicated test env; mocked backend | local production build for `@smoke`, ephemeral for the rest | Determines whether mutating tags may run at all, and what the guard checks |
| **Location** | beside the frontend (`frontend/tests/e2e/`); repo root | beside the frontend | Ownership. Put it where the people who will maintain it already look |
| **Auth** | headless form login; pre-captured `storageState`; API-minted session; no auth | `storageState` if any third-party or federated login exists | A federated/social login cannot be driven headless. Discovering this after twenty specs are written means rewriting all of them |
| **Data** | seeded fixture data; self-created per test; live content | self-created per test, with a seed for read-only routes | Specs written against live content become change detectors for other people's work |

## 2. Standard layout

```
tests/e2e/
├── playwright.config.ts     — projects (desktop/mobile/webkit), tag grep, reporters, locale, timezone
├── fixtures/
│   ├── env.ts               — every env knob centralised; specs never read process.env directly
│   ├── base.ts              — custom `test` extending @playwright/test with the project fixtures
│   └── signals.ts           — console + network collectors with allowlists (section 4)
├── pages/                   — page objects, one per route, intent-level methods
├── specs/                   — feature-grouped specs
├── utils/                   — multi-actor helpers, polling helpers, data builders
└── README.md                — target env, env vars, tag table, auth strategy, what is NOT covered
```

Two rules about this tree:

- **`env.ts` is the only file that reads `process.env`.** A spec that reads it directly is
  a spec nobody can retarget at a different environment.
- **`README.md` is not optional.** It is the first thing the next agent or contributor
  reads before extending the suite. If the `documentation-standards` skill is installed,
  place and format it per that skill; otherwise follow the project's own conventions.

## 3. Tagging convention

Bake this in on day one. Without it the suite cannot separate "runs on every pull request"
from "runs nightly against a dedicated environment", and the whole thing ends up disabled.

| Tag | Means | In the default grep? |
|---|---|---|
| `@smoke` | Fast, anonymous, idempotent. One assertion per route | yes |
| `@read` | Anonymous read-only navigation and UI checks | yes |
| `@semi` | Per-session state that expires on its own | no |
| `@write` | Mutates persistent shared state. Guard-skip on shared environments | no |
| `@multi` | More than one browser context (several actors). Guard-skip on shared environments | no |
| `@auth` | Needs `storageState` from a real login | no |
| `@flaky` | Known timing-sensitive; retries enabled | — |
| `@mobile` | Mobile-viewport specific | — |

Default grep in the config: `@smoke|@read`. CI overrides it with a single environment
variable (`<E2E_GREP_VAR>`). Every spec carries exactly one risk tag (`@smoke`, `@read`,
`@semi`, `@write`, `@multi`) plus any number of modifier tags.

## 4. The signal-collection fixture

Most e2e suites assert only on what they clicked and miss the regression sitting in the
console or the network tab right next to it. A page that renders correctly while throwing
an unhandled rejection and 500-ing a background request is a failing page.

The fixture attaches three collectors per test and asserts on them at teardown:

1. **Console errors** — `page.on('console')`, filtered to `error` (and `warning` if the
   project is strict).
2. **Failed requests** — `page.on('requestfailed')` plus `page.on('response')` for status
   `>= 400`.
3. **Unhandled rejections and page errors** — `page.on('pageerror')`.

Rules that make this pattern survive contact with a real app:

- **Soft-assert at the end of the test**, not hard. A hard assertion stops the test before
  the trace, screenshot and video are attached, and hides the real failure behind the
  signal failure. Soft assertions surface both.
- **Allowlist by exact shape, not by substring of a whole URL.** Match on
  `(method, path pattern, status)` so a new failure on the same host still fails.
- **A new "expected" error extends the allowlist — it never relaxes the assertion.** The
  allowlist is a reviewed, commented list; every entry says *why* it is expected and when
  it should be removable.
- **The allowlist lives beside the fixture, not inside individual specs.** One place to
  audit when someone asks "what noise are we ignoring?"

Illustration — allowlist entries with placeholder endpoints, not a real API surface:

```ts
// Illustration only. Replace every entry with the project's own known noise.
export const ALLOWED_SIGNALS = [
  // The shell probes the session endpoint on load; anonymous visitors get a 401 by design.
  { method: 'GET', path: /^\/api\/<resource>\/settings$/, status: 401 },
  // Third-party analytics/error beacons are blocked by browser policy and ad blockers.
  { method: 'POST', path: /^https:\/\/<analytics-host>\.example\.com\//, failure: 'blocked' },
  // Optional icon variant that not every deployment ships.
  { method: 'GET', path: /^\/icons\/<variant>\.png$/, status: 404 },
];
```

## 5. Page object rules

- **Methods are intent-level.** `showAllItems()`, not `clickAllItemsPill()`. A spec should
  read as a user story; when the pill becomes a dropdown, only the page object changes.
- **Locators are exposed as Playwright `Locator` objects, never as selector strings**, so
  the caller can chain `.first()`, `.filter()`, `.nth()` without the page object
  anticipating every use.
- **Prefer role and accessible name over CSS.** In order: `getByRole` with an accessible
  name → `getByLabel` → `getByText` → `data-testid` → CSS. Roles and names mirror what a
  user perceives and survive markup churn; a class name is an implementation detail that
  changes on the next refactor.
- **`data-testid` is the last resort, not the default.** Add one only when no semantic
  affordance exists *and* the team agrees to keep the attribute stable. Very often the
  correct fix is an `aria-label` on the element — it makes the test stable *and* improves
  accessibility, which a test id never does.
- **Every page object has `path` and `readyIndicator()`.** `goto()` navigates and waits for
  the indicator. Both come from a shared `BasePage`.
- **When a route's data state varies** (empty list vs populated list, feature flag on vs
  off), the page object exposes an indicator for each state and the spec branches or skips.
  A page object that assumes one state makes the suite red on a fresh environment.

## 6. Spec rules

- **One assertion per behaviour, not per element.** "The page renders" means the ready
  indicator is visible. Do not also assert the footer, the logo and three navigation links
  unless one of those *is* the behaviour under test.
- **Skip cleanly, do not fail noisily**, when a precondition is absent — no test account, an
  empty catalogue, a feature flag off. `test.skip(condition, reason)` with a reason that
  names the missing precondition.
- **Guard mutating specs against shared environments.** A `test.skip` at the top of every
  `@write`/`@multi` describe block that refuses to run when the base URL matches a shared
  host. This is the core safety rule from the top of this skill; it is a mechanism, not a
  comment saying "careful".
- **One browser context per actor in multi-actor flows.** Cookies and local storage *will*
  leak in a shared context and one actor's session becomes another's. A helper such as
  `spawnActors(browser, ['owner', 'guest-a', 'guest-b'])` returns isolated contexts; close
  all of them in `finally` so a mid-test failure does not leak browsers into CI.
- **Never assert on data the spec did not create**, except on routes explicitly seeded for
  read-only checks. "The first row is ours" is true until someone else uses the
  environment.
- **Name the spec after the behaviour**, not the component. `guest cannot edit a shared
  item`, not `EditButton.spec`.

## 7. Determinism

Flakiness is not bad luck; it is an un-pinned input. Pin all of them.

**No arbitrary waits.** `waitForTimeout` is banned outright — every occurrence is either a
race that will fail on a slower CI runner or a delay that will slow the suite forever.
Replace it with the condition you were actually waiting for:

| Instead of | Wait for |
|---|---|
| `waitForTimeout(500)` after a click | `expect(locator).toBeVisible()` / `toHaveText()` — Playwright retries the assertion |
| `waitForTimeout` before reading a list | `expect(rows).toHaveCount(n)` |
| `waitForLoadState('networkidle')` | `document.fonts.ready` plus an explicit element wait. Many apps have telemetry beacons, polling or socket heartbeats, so network idle **never** arrives |
| Sleeping until an async job finishes | `expect.poll(...)` with a deadline and a message naming what never arrived |
| Sleeping for an animation | Disable animations globally (section 12.2) |

**Deterministic data and environment:**

- **Pin `locale` and `timezoneId` in the config.** `getByText` matches translated copy, so
  a suite that inherits the runner's system locale reads whatever language CI happens to
  be in. If the `i18n-conventions` skill is installed, the locale the suite pins is the
  project's source locale as defined there.
- **Pin the viewport per project.** Layout assertions are meaningless without it.
- **Freeze or control time** for anything that renders a relative date, a countdown or a
  greeting keyed to the hour.
- **Every created object carries a unique per-run suffix**, so two concurrent runs never
  collide and an orphan is identifiable.
- **Seed via API or a fixture script, not through the UI.** Driving the UI to reach a
  precondition makes every spec depend on every other feature's markup.
- **Deterministic ordering.** If the backend does not guarantee an order, assert on set
  membership, not on index.

## 8. Locator discovery through a browser-automation MCP

This is the legitimate use of an interactive browser: finding the affordances for a new
page object.

1. Navigate to the route.
2. Enumerate the page's affordances in one evaluation — `aria-label`s, role-able elements,
   heading text and any `data-testid`s. One structured dump is cheaper than a full
   accessibility snapshot and gives a better starting point.
3. Pick the most stable affordance per element, in the section 5 order.
4. Close the browser.

Do **not** transcribe the interactive session into a spec. The spec runs headless, in
parallel, against a fresh context, with none of the state the exploratory session
accumulated. Write it self-contained from the page object.

## 9. First-time setup

1. Confirm the five decisions (section 1).
2. Scaffold `tests/e2e/{playwright.config.ts, fixtures/, pages/, specs/, utils/}`.
3. Add to the package manifest: the `@playwright/test` dev dependency and scripts for
   `test:e2e`, `test:e2e:smoke`, `test:e2e:read`, `test:e2e:full`, `test:e2e:ui`,
   `test:e2e:report`, `test:e2e:install`.
4. Ignore the generated artefacts in version control: the report directory, the results
   directory, the browser cache directory, and **every file under the auth-state
   directory** — a committed `storageState` is a leaked session token.
5. Write `BasePage`, one page object and one `@smoke` spec for the public landing route.
   Get it green locally before going wide.
6. Inventory the product surface and categorise every route by risk (anonymous-read /
   semi / write / multi / auth).
7. Write the `@smoke` block: every route's ready indicator plus every expected redirect.
8. Layer the read-only specs. Scaffold `@write`/`@multi` as `test.fixme` with the shared
   environment guard already in place, so the guard exists before the first mutating spec.
9. Write `tests/e2e/README.md`: target environment, environment variables, the tag table,
   the layout, the signal pattern, the auth strategy, and an explicit "not covered yet"
   list.
10. Wire CI to run `@smoke|@read` on pull requests and the full grep on a schedule. If the
    `cicd-build-deploy` skill is installed, add it as a stage there; otherwise follow the
    project's own pipeline conventions.

## 10. Extending an existing suite

1. **Read `tests/e2e/README.md` first.** It states the conventions actually in use, which
   beat the ones in this skill.
2. **Look in `pages/` before writing a locator.** If the page object exists, extend it.
3. **Pick the risk tag deliberately.** A new spec that mutates persistent state is `@write`
   plus the guard, no exceptions.
4. **Use the existing signals fixture.** Do not write a second collector.
5. **If a new locator does not fit the page object's style, change the page object.** Specs
   stay at intent level.
6. **Iterate with the UI mode runner**, and open the trace viewer on failure instead of
   adding logging.
7. **Run the new spec twice in a row** against the same environment before committing. A
   spec that only passes on a clean slate is not isolated.

## 11. Common pitfalls

| Pitfall | What actually happens | Fix |
|---|---|---|
| No `data-testid` anywhere in the codebase | Specs reach for CSS classes and break on the next refactor | Use `getByRole`/`getByLabel`; add a few `aria-label`s rather than sprinkling test ids |
| `getByText` on translated copy | The suite reads whatever locale the runner defaults to | Pin `locale` in the config; prefer role + accessible name |
| Federated or third-party-only login | Cannot be driven headless, at all | Document the `storageState` bootstrap; skip `@auth` specs when the state file is absent |
| Specimen/story pages do not render every variant | Assertions target a variant that is not on the page | Read the specimen source before asserting on it |
| Mutating specs reach a shared environment | Real data is corrupted and the suite gets banned | The base-URL guard (section 6) — mechanical, not a comment |
| Multi-actor flows in one context | Cookies leak; one actor's auth becomes another's | One `browser.newContext()` per actor; close in `finally` |
| Hard-asserting the collected signals | The test stops before artefacts are attached | `expect.soft(...)` |
| Treating every visual change as a spec failure | Structural specs cannot see CSS-only regressions anyway | Add the design layers of section 12 instead of over-asserting in functional specs |
| Retries used to hide a race | The suite passes and the bug ships | Retries are for genuinely non-deterministic infrastructure; fix the wait instead |

## 12. Design-review automation

"Find design inconsistencies / drift / wrong spacing / wrong colours" is a **different
problem** from functional e2e. It is four different problems, each with its own cost and
signal profile. Do not pick one — layer them. The token vocabulary these layers check
against is defined by the `design-system-authoring` skill in this pack.

### 12.1 Layer 1 — token-compliance walker (cheap, deterministic, no flakes)

Walk every visible element on every route, read the computed `color`, `background-color`,
`border-color`, `font-family`, `font-size`, `font-weight` and `border-radius`, and flag
anything that does not match the live token set — extracted from `:root` and any other
token-scoped class present on the page.

The implementation details that decide whether this layer is useful or noise:

- **Resolve tokens through a probe element, never as strings.** Append a hidden `div`, set
  `style.color = 'var(--<token>)'`, read `getComputedStyle(probe).color`. Now tokens and
  elements are compared in the same representation (`rgb()`, computed `px`).
  String-comparing `#08080a` against `rgb(8, 8, 10)` fails forever.
- **Infer the constraints from what the system actually defines.** If no `--font-weight-*`
  token exists, do not check font-weight at all. A design system constrains exactly what it
  tokenises; without this rule every legitimate `font-weight: 400` is reported as drift.
- **Name-hint filtering: the token's name and its value must both agree** before it joins a
  category. Otherwise a `--z-sticky: 100` lands in the font-weight set (because `100`
  matches a weight-shaped pattern) and ruins every font-weight check.
- **Default-OK values** are exempt: `0px`, `transparent`, `none`, and inherited pure
  black/white.
- **Wait for `document.fonts.ready` before sampling.** Otherwise the computed font-family
  is the browser's fallback serif and every page is reported as "wrong font".
- **Report-only by default.** Write findings to a fixed directory (`.design-review/`),
  attach them to the HTML report, log a count — but do not fail. Keep a single
  `FAIL_ON_VIOLATIONS` constant so CI gating is a one-line change later.
- **Deduplicate per `(property, value)` tuple** with a count of how many elements share it,
  and list one exemplar selector. A report listing 200 elements is a report nobody reads.

### 12.2 Layer 2 — visual regression on specimens (low-flake when scoped)

`expect(specimen).toHaveScreenshot()` against committed baselines, **scoped to a
component-catalogue or design-book route only**. Live pages carry thumbnails, timers,
animations, relative dates and scrollbars — a flakiness factory.

- Inject CSS that disables all animations, transitions and caret blinking.
- Mask `video`, `audio`, and every live-data or timer element.
- Run CI on the same OS and browser build as the baseline was captured on, or fight
  font-rendering diffs forever.
- Document the snapshot-update flow loudly in the e2e README — every reviewer will need it.
- Report-only at first: catch the assertion, log the diff path, do not fail.

### 12.3 Layer 3 — geometry consistency rules (per repeating group)

For each known repeating group — a card grid, list rows, navigation items, filter tabs,
table rows — assert:

- Heights and widths match within ±1px.
- Border radii match exactly.
- Gaps within the first row or column are uniform within ±1px.

Implementation notes: collect bounding rectangles and computed styles for the whole group
in **one** `evaluateAll` round-trip; detect the axis from the X/Y spread of the group rather
than hardcoding it; and stop accumulating gaps at the first negative gap, which signals a
wrap onto the next row.

### 12.4 Layer 4 — vision audit (on-demand, never in CI)

A standalone script driven by Playwright — **not** a spec in the suite. It screenshots every
route and every specimen, sends each image to a vision-capable model with a structured
rubric, and aggregates the findings into a Markdown report.

- **Structured output only**: `{type, severity, location, description, suggested_fix}`,
  validated on parse. If the `llm-pipeline-rules` skill is installed, follow its rules for
  structured output, retries and cost control; otherwise follow the project's own.
- **The rubric explicitly forbids generic praise** and "this could be better" findings. Each
  finding must name an element and a concrete change.
- **Call the provider's HTTP API directly**; do not add an SDK dependency to a repo that
  otherwise has none.
- **Skip cleanly when the API key is absent**, printing the variable name — the script must
  be safe to run on any machine.
- **Budget it.** Roughly one vision call per page; a default plan of 10–15 pages. Run it via
  a dedicated script command, on demand, never as part of the test run.
- The key comes from the project's secret handling at run time — never a literal in the
  script. If the `secrets-management` skill is installed, follow its contract.

### 12.5 Tags and pitfalls for the design layers

| Tag | Layer |
|---|---|
| `@design` | Umbrella for all design specs |
| `@design-tokens` | Layer 1 |
| `@design-vr` | Layer 2 |
| `@design-geometry` | Layer 3 |

Layer 4 is a script, not a tag.

- **Comparing source token values to computed styles** — always resolve through a probe.
- **Treating "no token of category X exists" as "everything is drift"** — infer constraints.
- **A weight-shaped matcher swallowing z-index values** — name hint *and* value must agree.
- **Visual regression on live pages** — restrict it to the component catalogue.
- **`networkidle` never settling** — use `document.fonts.ready` plus element waits.
- **A first run with no baselines turning CI red** — commit baselines from a controlled
  update run *before* enabling the layer.

## 13. When not to use this skill

- One-off fetch of a URL → use an HTTP client.
- Logic provable by a unit or component test → write that; it runs in milliseconds.
- Backend-only change → an API or integration test.
- "Does this CSS render right, right now?" → drive the browser directly; do not add a
  permanent spec for an ephemeral check.
- A one-time migration verification → a script, not a committed spec.

## Definition of done

- [ ] The five decisions of section 1 are recorded in `tests/e2e/README.md`.
- [ ] `env.ts` is the only file reading environment variables.
- [ ] Every spec carries exactly one risk tag; the default grep is `@smoke|@read`.
- [ ] The signals fixture is attached to every test and soft-asserted at teardown, with a
      commented allowlist that explains each entry.
- [ ] Locators use role and accessible name; every `data-testid` and CSS selector in the
      suite has a written reason.
- [ ] `grep -r waitForTimeout` over the suite returns nothing.
- [ ] `locale`, `timezoneId` and viewport are pinned in the config.
- [ ] Mutating tags are guarded by a base-URL check that skips on shared environments, and
      the guard is tested by pointing the suite at a shared URL and observing the skip.
- [ ] No `storageState` file is tracked in version control.
- [ ] The suite passes twice in a row against the same environment, and leaves no data
      behind.
- [ ] The design layers are report-only until their baselines and allowlists are reviewed.
- [ ] Be honest about maturity: a spec that has never been executed against the target
      environment is documented as such, not implied to be green.

## Project delta

The consuming repo supplies:

- **Target environments and their base URLs**, plus which hostnames count as shared and
  therefore trigger the mutating-spec guard.
- **The suite's location** and the exact commands for each script (`test:e2e`, smoke, read,
  full, UI mode, report, browser install).
- **Environment variable names**: base URL, tag grep override, auth-state path, test
  account identifiers, and the vision-audit key name.
- **Auth strategy**: how `storageState` is produced, by whom, how often it expires, and
  what happens to `@auth` specs when it is missing.
- **The route inventory** with each route's risk category and its ready indicator.
- **The seeding mechanism**: the API or script that creates precondition data, and the
  per-run unique suffix convention.
- **The signal allowlist**: the project's known-noise endpoints and third-party beacons,
  each with a reason.
- **Design-system inputs**: where the tokens are defined, which route is the component
  catalogue, which repeating groups get geometry rules, and the OS/browser build the visual
  baselines were captured on.
- **The source locale** the suite pins, and the timezone.
- **CI wiring**: which grep runs on pull requests, which runs on a schedule, and where
  reports and traces are published.
