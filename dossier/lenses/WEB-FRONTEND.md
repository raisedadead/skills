# Lens — Web frontend

For browser UI work — React/Vue/Svelte/Astro/Solid/Qwik, with
Playwright for behavioural + visual, vitest/jest for unit, and
SSR / hydration concerns.

## Surface vocabulary

- **Unit:** component (`Modal`, `Combobox`) / page-level slug (`/sidebar-layout`).
- **Output:** PNG snapshot, behavioural-spec assertion (computed style, role/state, text), DOM tree.
- **Contract:** prop API + ARIA role/state + emitted events + CSS token usage.

## Specific gates (meta-gate extensions)

- **CSS-token discipline.** No hex literals in component styles. Strip block comments, regex offenders.
- **`type=button` on every form-less button.** Walk components, regex offenders.
- **`data-testid` only in tests.** No `data-testid` in production HTML — use roles + accessible names.
- **`client:*` declared on every stateful island.** For Astro: every `.astro` with a stateful import has a `client:` directive.
- **Behavioural-spec ratchet.** `READY ⊆ REQUIRED_AT_GA` slug list. New component → append to `READY` in same commit.
- **Visual-snapshot manifest.** `screenshotted` set is explicit; meta-test asserts every `REQUIRED_VISUAL` slug has a golden.

## Output rebaseline specifics

| Step              | Command                                                           |
| ----------------- | ----------------------------------------------------------------- |
| Build             | `pnpm build` (Astro/Next/Vite — playwright reads `dist/`)         |
| Unbaselined run   | `pnpm exec playwright test`                                       |
| Read failures     | screenshot diffs in `test-results/`                               |
| Accept goldens    | `pnpm exec playwright test --update-snapshots`                    |
| Scoped rebaseline | `pnpm exec playwright test <name> -g '<grep>' --update-snapshots` |

Goldens land in `tests/visual/__snapshots__/` (or per-runner config).

## Probe specifics

- File: `_probe-<slug>.behaviour.spec.ts`
- Runner: `rtk proxy npx playwright test -g _probe-<slug>` (or `--reporter=list`)
- Dump shape: `page.evaluate(() => ({ ... computed/state ... }))` then `console.log(JSON.stringify(...))`.
- Common dump targets: `getBoundingClientRect()`, `getComputedStyle()`, `getAttribute('aria-*')`, `data-state`, hydration markers.

## Stack footguns

- **`client:visible` hydration race.** Fill races hydrate. → promote to `client:load`.
- **React `<select defaultValue>` in Astro.** SSR ignores; explicit `selected` on option needed.
- **Astro preview serves stale `dist/`.** Always build between source change and playwright run.
- **Parent-child Context across islands.** Wrap parent + children in one React component; hydrate the wrapper.
- **jsdom missing `scrollIntoView`.** Polyfill in `beforeAll`.
- **Visually-hidden input not clickable.** Click the wrapping `<label>`.
- **Selector matches code-panel text.** Discriminate via `data-state="open"` (or live-only attribute).
- **ark-ui Dialog persists on close.** Qualify with `[data-state="open"]`.
- **Layout collapses to min-content.** Add `width: 100%` alongside `max-width` when parent is `align-items: stretch`.
- **Component CSS `min-height: 100vh` overrides inline.** Set inline `minHeight: '0'` or null.

## Phase shape hint

Typical sub-phases for a web-frontend phase:

- P0 — runner + meta-gate scaffold
- P1 — behavioural backfill (existing components → behavioural specs)
- P2 — visual rebaseline policy + snapshot manifest
- P3 — token / chrome polish (CSS gates)
- P4 — accessibility ratchet (a11y axe-core gate)
- P5 — coverage threshold ratchet
- P6 — release / GA cut + changeset
