---
name: react-conventions
description: Component boundaries, state placement, data fetching, effects, forms, lists, memoisation, styling and accessibility for a React or React Native application, plus the local verification gate. Use when writing or reviewing React or React Native code, adding a component, screen or hook, deciding where a piece of state belongs, wiring a data fetch, writing or debugging a useEffect, building a form, handling loading and error states, splitting platform-specific code, or when asked "where does this component go", "should this be local state or context", "why does this re-render forever", "why does this fetch in a loop", "do I need useMemo here", "container or presentational", "how do we fetch data on this screen", "where do the design tokens go", or "is this frontend work done".
license: Apache-2.0
metadata:
  source: glotyuids/engineering-skills
  version: 0.1.1
---

# React conventions

Conventions for structuring a React or React Native application, merged from two
independently hardened frontend codebases — one web SPA and one mobile app.

**This skill defines only the application-internal structure and code conventions**: the
import/layering rule, directory tree, component boundary, state placement, data fetching,
effects, forms, lists, memoisation, and the local verification gate. It does **not**
define visual design or token values, translation catalogue mechanics, end-to-end test
authoring, bundler or CI configuration, or the backend contract — those belong to the
design-system, i18n, testing, infrastructure and backend skills respectively. Where a
project's own conventions already exist and differ, the project wins; adapt names to an
existing repo rather than renaming it, unless the user explicitly decides otherwise.

`[!]` below marks three rules whose violation caused a real production defect in these
codebases — a request storm, an unbounded retry loop, and an app-wide crash with no
diagnostic surface. They are not style preferences.

---

## 1. The import rule

This is the one non-negotiable. Every other section serves it. Dependencies point
**inward and downward**; nothing below reaches up.

| Layer | May import | Must never import |
|---|---|---|
| `design/` tokens, `types/`, `i18n/` catalogues | nothing from the app | anything |
| `api/` | `types`, config, generated contract types | components, screens, state providers |
| `platform/` | `types`, `api` types, `i18n` | components, screens, state providers |
| `state/`, `hooks/` | `api`, `platform`, `types` | screens, components |
| `components/` | `design` tokens, `i18n`, `types` | `api`, `platform`, state providers, screens |
| `screens/` | components, hooks, state, `i18n`, tokens | `api` and `platform` **directly** |
| app entry, router | everything | — |

Two consequences worth stating out loud, because they are where the rule actually bites:

- **A file in `components/` that imports the API client is not a component.** It is a
  container, and containers live at the screen layer or inside a hook.
- **A screen does not call `fetch` (or the API client) itself.** It calls a hook that
  does. This is what makes a screen renderable in a test, a story or a design review
  without a network.

A new app may legitimately start with only `components/`, `screens/` and `api/`. Add the
other directories as the app acquires real behaviour — do not scaffold empty folders to
look complete.

## 2. Directory layout

```
<app-root>/src/
├── components/        # reusable presentational primitives (Button, Card, Chip …)
├── screens/           # one per route; composition + wiring  (or pages/)
├── state/             # cross-screen providers and the hooks that own them
├── hooks/             # reusable behaviour not owned by one screen
├── api/               # transport: client, typed errors, per-resource modules,
│   └── generated/     #   and contract types generated from the API schema
├── platform/          # native/browser capability adapters behind local interfaces
├── design/            # tokens — the only file allowed to contain literals
├── i18n/              # catalogues + the translate function
├── utils/             # pure, dependency-free helpers
└── types/             # shared types not owned by api/ or domain modules
```

Naming: component and screen files are `PascalCase.tsx` and export the same name; hooks
are `useThing.ts`; everything else is `camelCase.ts`. A directory gets an `index.ts`
barrel only when it is a boundary other layers import through (`api/`, `platform/`,
`hooks/`) — never as a re-export of everything in `components/`, which defeats
code-splitting.

`utils/` is for genuinely pure helpers. It is not a landfill: if a helper needs the API
client, a token or a React import, it belongs in `api/`, `state/` or `hooks/`.

## 3. The component boundary

Two orthogonal splits. Keep them orthogonal.

**Presentational vs container** — about data.

| | Presentational | Container |
|---|---|---|
| Gets data from | props | hooks, providers, the API |
| Owns | rendering, layout, local UI state | fetching, mutation, orchestration |
| Imports `api/` | never | yes |
| Testable without a network | yes | no |
| Lives in | `components/` | `screens/`, or a `use*` hook |

**Screens vs components** — about reuse.

- `screens/` is one file per route. A screen composes components, reads state, passes
  callbacks down. It is the only place navigation is triggered.
- `components/` is everything reused by more than one screen, plus the design primitives.
  A component never knows which screen renders it.
- A chunk of markup used by exactly one screen stays in that screen's file until it is
  either reused or long enough to obscure the screen. Extracting a
  single-use component to a shared directory is premature; extracting it to a sibling
  file in a per-screen folder (`screens/<area>/`) is fine.

Split a component when it acquires a second reason to change, not at a line count. Prop
count is the better smell: more than about six props, or a boolean prop that switches
large branches of the render, usually means two components wearing one name.

## 4. Where state belongs

Pick the **narrowest** row that works. Widening later is cheap; narrowing after ten
consumers have appeared is not.

| Kind | Home | Belongs here when | Smell that it is in the wrong place |
|---|---|---|---|
| Local UI | `useState` in the component | one component cares — open/closed, hovered, draft input | passed down through three layers |
| Lifted | nearest common ancestor | two siblings must agree | lifted to the root "so everyone can see it" |
| Derived | computed during render | it is a function of existing state or props | it has its own `useState` and an effect keeping it in sync |
| Server data | a query/cache layer keyed by request | it came from the network | copied into a global provider |
| URL | route params and search params | it should survive a reload, a back button or a shared link | a tab index or a filter set kept only in memory |
| Global | one provider per concern (`state/`) | genuinely app-wide: session, theme, locale, live connection | it holds a list of entities fetched from the API |
| Module scope | a module-level `Map` or ref | a bounded cache or a singleton connection | it holds anything a component must re-render on |

Rules:

1. **Server data is a cache, not application state.** It is owned by the server, it goes
   stale, and it needs refetch, invalidation and per-request loading/error status. Put it
   behind a fetching layer keyed by the request. Copying a fetched entity into a global
   store gives you two copies with no invalidation story, and the one users see is the
   stale one.
2. **Do not derive state.** If a value can be computed from state or props during render,
   compute it. See §6.
3. **One provider per concern, not one god provider.** Session, theme, locale and live
   connection are four providers. A single `AppContext` re-renders every consumer when
   any of the four changes.
4. Context is a transport for state, not a state manager. Splitting a provider's value
   into a stable-actions object and a changing-data object is the cheap fix when a
   provider causes wide re-renders.
5. Access tokens live **in memory** — never in `localStorage` or an unencrypted key-value
   store. A long-lived refresh credential, where the platform has a secure store, goes
   there and nowhere else.

## 5. Data fetching

**Every asynchronous surface handles all three of loading, error and empty.** Not two.
Shipping "the happy path plus a spinner" is the single most common review finding in
these codebases.

| State | Must render | Common mistake |
|---|---|---|
| Loading | a skeleton or spinner sized like the real content | rendering nothing, so loading looks like empty |
| Error | a human-readable message **and a retry affordance** | a raw exception string, or a silent blank screen |
| Empty | an explanation and the action that fills it | the same blank space as loading |
| Success | the content | — |

Empty and loading must be visually distinguishable, and error must be recoverable without
a reload. Write the empty-state copy at the same time as the component — a component
whose empty state is "TODO" is not done.

Mechanics:

1. **Prefer an established server-cache library** (a query/SWR layer) over hand-rolling.
   It gives deduplication, caching, invalidation and status for free. If the project
   hand-rolls — which is a legitimate choice for a small surface — the hand-rolled hook
   still owes the same contract: status triad, cancellation, and bounded retry.
2. **Cancel on unmount and on key change.** Either an `AbortController` passed to the
   request, or a `cancelled` flag checked before every `setState` in the cleanup:

   ```ts
   useEffect(() => {
     let cancelled = false;
     load(id).then(r => { if (!cancelled) setData(r); });
     return () => { cancelled = true; };
   }, [id]);
   ```

3. `[!]` **Retries are bounded and backed off, and the retry state lives inside the
   effect.** An unbounded client retry against a degraded backend is a self-inflicted
   denial of service, and storing the attempt counter in `useState` makes it an effect
   dependency, so each failure re-triggers the effect that produced it. Cap the attempts
   (three is a reasonable default), use exponential backoff with a ceiling, and keep the
   timer and counter in local variables inside the effect body.
4. **All transport lives in `api/`**: one client, one typed error class carrying status
   and code, one place that attaches auth headers. Components and screens never call
   `fetch`.
5. **Generate contract types from the API schema** rather than hand-writing them, and
   regenerate in the same change as the backend contract. If the `api-and-events` skill
   is installed, follow it for the contract itself; otherwise follow the project's own.
6. Never put user data or a token in a query string. Never render server-supplied HTML
   without sanitising it.

## 6. The effect rule

**An effect synchronises React with something outside React.** Subscriptions, timers,
imperative DOM or native APIs, analytics, manual store bridges. That is the whole list.

`[!]` **Using an effect to derive state is the most common defect in a React codebase.**
The pattern — state, plus an effect that sets a second piece of state from the first —
costs an extra render pass, guarantees at least one frame of inconsistent UI, and turns
any mistake in the dependency array into an infinite render or request loop. In these
codebases it has produced both a render loop and a request storm against a live backend.

| Instead of an effect that… | Do this |
|---|---|
| computes a value from props/state | compute it during render |
| computes an expensive value from props/state | compute it during render, wrap in `useMemo` **only** if measured (§9) |
| resets state when a prop changes | give the component a `key` so React remounts it |
| runs code in response to a click | put the code in the event handler |
| fetches on mount | a fetching hook (§5) — still an effect underneath, but one you do not hand-write per screen |
| stores something derived for a child | pass the computed value down |

Further rules:

- **Every effect that starts something returns a cleanup that stops it.** Subscriptions,
  timers, listeners, sockets, watchers. No exceptions.
- **The dependency array is not a tuning knob.** Do not silence the exhaustive-deps lint
  rule to stop a loop — the loop is telling you a dependency is unstable. Fix it by
  moving the value inside the effect, stabilising it with `useCallback`/`useMemo`, or
  keeping it in a ref when the effect must read the latest value without re-subscribing.
- A value read by an effect but which must never re-trigger it belongs in a ref, and the
  comment saying so belongs next to it.
- Do not read layout or measure in a plain effect if the result affects paint; use the
  layout-effect variant, and only there.

## 7. Forms

A form is field state, validation and a submission. Each of the three has one right home.

- **Controlled by default**, with exactly one source of truth per field. Reach for an
  uncontrolled input (a ref) only for file inputs, or for a *measured* typing-performance
  problem on a large form.
- **Initialising from a prop is not the same as syncing to it.** Seed the state once; when
  the form must reset because its subject changed, remount it with a `key` rather than
  adding an effect that writes props into state (§6).
- **Past about three fields, or as soon as validation is interdependent, use a form
  library** instead of a `useState` per field. Below that, hand-rolled is fine.
- **Validate on blur and on submit.** Surface a field's error on blur or after the first
  submit attempt — never on the first keystroke, which reads as the form shouting at the
  user for starting to type. Re-validate as they correct it.
- **The submit handler is an event handler, never an effect.** Submitting from an effect
  that watches a `shouldSubmit` flag double-submits the moment the dependency array is
  wrong.
- **Disable the submit control while the request is in flight**, and re-enable it on both
  the success and the failure path. This, not a debounce, is the fix for double submission.
- **Server-side validation errors land on the field they belong to**, with a form-level
  summary reserved for errors that belong to no field. A toast that disappears on a timer
  is not error handling for a form.
- **Every input has a programmatic label**, its error message is linked to it and the
  field is marked invalid, and focus moves to the first invalid field on a failed submit
  (§11). Do not signal invalidity with a red border alone.
- Never block paste on a password field — it defeats password managers and buys nothing.

## 8. Lists and keys

- **`key` is a stable identity from the data**, on the outermost element produced per
  item.
- **Array index is a key only for a list that is append-only and never reordered,
  filtered or deleted from.** Otherwise React reuses the wrong instance and per-row local
  state — an open menu, a focused input, a pending toggle — attaches to the wrong row.
- A key is not a prop: if a child needs the id, pass it separately.
- Never key by array index and then animate the list.
- Long lists get virtualisation only when measured to need it; on mobile use the
  platform's virtualised list component rather than mapping into a scroll view.

## 9. Memoisation

**Memoise against a measured problem, not against a hypothesis.** `useMemo`, `useCallback`
and `memo` each add a dependency array to maintain and a comparison to run; applied
speculatively they make the code harder to change and measurably slower.

Order of attack when something is actually slow:

1. Measure with the profiler. Identify which component re-renders and why.
2. Fix the structure: move state down, split the provider, pass elements as `children`
   so they are not re-created by the re-rendering parent.
3. Only then memoise, at the boundary the profiler pointed at.

Two facts that decide most cases:

- **`useCallback` on a handler does nothing for render count unless the consumer is
  memoised.** Its legitimate uses are stabilising a dependency of an effect or another
  hook, and feeding a memoised child. Passing a `useCallback` to a plain component is
  pure overhead.
- **`memo` on a component whose props include a fresh object or array literal never
  hits.** Memoise the props before memoising the component, or do neither.

Always legitimate without measurement: memoising a value that is an effect dependency,
and memoising a genuinely expensive pure computation (parsing, large sorts, layout maths)
that runs on every keystroke.

## 10. Styling

- **Code references design tokens, never literals.** Colours, spacing, radii, font sizes,
  weights, shadows and border widths come from the token module. A hex code, a raw `px`
  font size or a numeric `borderRadius` outside that module is a bug, and one grep in CI
  is the cheapest possible test for it.
- Layout values that are not design decisions (a flex ratio, `overflow: hidden`) are fine
  inline. The rule is about the design vocabulary, not about every number.
- Do not encode meaning in colour alone — pair it with a label, an icon or a shape.
- Support both colour schemes from the start if the product has a theme toggle; a
  hardcoded light-mode surface is invisible work to undo later.
- If the `design-system-authoring` skill is installed, follow it for token structure,
  component specs and the drift audit; otherwise follow the project's own conventions.

## 11. Accessibility

The floor, not the ceiling. All of it applies to both web and native, with different API
names.

| Concern | Web | React Native |
|---|---|---|
| Semantics | real `<button>`, `<a>`, `<nav>`, `<h1…h6>` — never `<div onClick>` | `accessibilityRole` on `Pressable` |
| Name | `<label for>`, or `aria-label` when no visible label | `accessibilityLabel` |
| State | `aria-expanded`, `aria-invalid`, `aria-busy` | `accessibilityState` |
| Live updates | `aria-live` on the region | `accessibilityLiveRegion` / announcements |
| Hit target | min 44×44 CSS px | min 44pt, extended with `hitSlop` when the visual is smaller |
| Focus | visible focus ring; never `outline: none` without a replacement | — |
| Motion | honour reduced-motion | honour reduce-motion |

Plus:

- **Focus order follows visual order.** No positive `tabIndex`.
- **Move focus deliberately** on route change (to the new heading) and on opening a
  modal (into the modal, trapped, returned to the trigger on close).
- **Every interactive element is reachable and operable by keyboard**, including custom
  ones. If you built it out of a `div`, you now owe it `role`, `tabIndex={0}` and
  Enter/Space handlers — which is the argument for using the real element.
- **Every image has `alt`**; decorative images get `alt=""`, not a description.
- Check contrast on the actual foreground/background pairs you ship, including text on
  tinted surfaces and on images.
- All user-facing strings go through the translation layer, never a literal in JSX. If
  the `i18n-conventions` skill is installed, follow it; otherwise follow the project's
  own conventions.

## 12. React Native specifics

1. **Platform-specific code lives behind one boundary.** A `platform/` directory exports
   capability providers (location, notifications, camera, storage, maps) as objects
   behind locally-defined types. Screens and components consume the type, never the
   underlying SDK. Swapping or stubbing a provider is then a one-file change.
2. **The second permitted boundary is the platform file extension** — `Component.ios.tsx`,
   `Component.android.tsx`, `Component.web.tsx` — and only for a whole component with an
   identical prop type. `Platform.OS` branches scattered through screens are the
   anti-pattern this replaces; a couple of `Platform.OS` checks inside `platform/` are
   fine.
3. `[!]` **Wrap each screen in an error boundary.** An uncaught render error unmounts the
   entire React tree, and a release build has no development overlay, no console and no
   log surface — the user sees a blank or dead app and you get no stack. A boundary that
   renders the message and stack on screen, plus a reset, is the difference between a
   two-minute diagnosis and an unreproducible report. Error boundaries catch render
   errors only; async and event-handler failures still need explicit handling (§5).
4. **Do not commit generated native project directories** (`ios/`, `android/`) unless the
   project has intentionally decided to eject or to add a custom native module, and has
   written that decision down. Once they exist, the managed config file stops
   regenerating them and the two silently diverge — a change to app config appears to do
   nothing, and the divergence surfaces at store-submission time.
5. If the app also targets web through a compatibility layer, any component using a
   native-only module needs a web counterpart or an explicit unsupported state. A screen
   that throws on web is worse than one that says the feature is mobile-only.
6. Lists use the virtualised list component; images use the framework's image component
   with explicit dimensions; anything reaching the bezel respects safe-area insets.

## 13. Verification gate

Do not claim frontend work is complete until all of these are green, locally, on the
change as it stands:

- [ ] **Typecheck** — `tsc --noEmit` (or the project's `typecheck` script), zero errors
- [ ] **Lint** — the project's config, zero errors and zero new warnings, including the
      React hooks rules
- [ ] **Tests** — unit and component tests pass
- [ ] **Production build** — the real build command, not the dev server, succeeds
- [ ] **The three states rendered** — every async surface touched shows loading, error
      and empty correctly, verified, not assumed
- [ ] **No new literals** — no hardcoded colours, spacing or user-facing strings

Running a subset and reporting "done" is the failure mode this gate exists to prevent.
"It renders on my machine" is not the gate; the whole list is.

Two honest caveats:

- **Do not start a dev server to verify unless the user asks.** Prefer the production
  build, targeted typecheck and lint, and static inspection of the output. If browser
  verification would genuinely help, say so and wait to be asked.
- **Many React repos have no test runner at all.** If this one does not, say that
  explicitly rather than reporting a green test step you did not run. If the
  `ui-test-playwright` skill is installed, follow it when adding end-to-end coverage;
  otherwise follow the project's own conventions.

---

## Project delta

The consuming repository must supply:

1. **App root and source root** — where `src/` lives, and whether the app is standalone
   or one workspace of a monorepo.
2. **Framework and renderer** — React DOM or React Native, the router in use, and the
   build tool, so "the production build command" is concrete.
3. **Directory names in force** — `screens/` or `pages/`, `state/` or `context/`, and any
   directory in §2 the project omits.
4. **The state layer** — which provider set exists, and whether a server-cache library is
   in use or fetching is hand-rolled.
5. **The API layer** — client location, the typed error class, how auth headers are
   attached, and whether contract types are generated and by what command.
6. **The token module path**, and the CI grep that enforces "no literals".
7. **The translation layer** — the translate function and where catalogues live.
8. **Verification scripts** — the exact `typecheck`, `lint`, `test` and `build` commands,
   and which of them do not exist yet.
9. **React Native only**: the `platform/` provider set, whether native project
   directories are committed and why, and whether web is a supported target.
10. **Accessibility target** — the conformance level the project commits to, and any
    audited exceptions.
