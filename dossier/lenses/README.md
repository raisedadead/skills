# Lenses

Stack-specific addons to the core dossier workflow. The core
(`SKILL.md` + `references/`) is stack-neutral; lenses encode
the conventions, gates, and footguns of one stack.

Pick at most **one** lens per phase. Symlink it (or copy) into
`.dossier/LENS.md` so it's always next to the other working
docs.

```bash
ln -sfn ../../<skill-dir>/lenses/BACKEND-API.md .dossier/LENS.md
```

The init script does this for you when you pass `--lens=<name>`.

## Available lenses

| Lens                 | Use when the work is …                                              |
| -------------------- | ------------------------------------------------------------------- |
| `WEB-FRONTEND.md`    | Browser UI — React/Vue/Svelte/Astro, Playwright, hydration, CSS.    |
| `BACKEND-API.md`     | HTTP / RPC service — OpenAPI / gRPC, DB migrations, idempotency.    |
| `CLI-TOOL.md`        | Shell-callable binary — flag parsing, exit codes, golden stdout.    |
| `LIBRARY-PACKAGE.md` | Distributed library / SDK — public API surface, semver, types.      |
| `DATA-PIPELINE.md`   | ETL / dbt / orchestrated jobs — schema, fixture roundtrip, lineage. |
| `INFRA-IAC.md`       | Terraform / Pulumi / Helm / k8s — plan-only diff, drift detection.  |
| `MOBILE.md`          | iOS / Android / RN / Flutter — sim runs, snapshot images, native.   |
| `ML-PIPELINE.md`     | Model training / evals — eval-set gates, regression bands.          |

## What a lens contains (uniform structure)

Every lens follows the same outline so the agent can pattern-match
fast:

1. **Surface vocabulary.** What "the unit" / "an output" / "a
   contract" means in this stack.
2. **Specific gates.** Meta-gate examples for this stack
   (extends `META-GATE.md`).
3. **Output rebaseline specifics.** Build/regenerate command,
   golden artefact paths, accept command (extends
   `OUTPUT-REBASELINE.md`).
4. **Probe specifics.** Throwaway-spec runner + dump shape
   (extends `PROBE-PATTERN.md`).
5. **Stack footguns.** Failure modes catalogued from prior
   work in this stack (extends `FAILURE-MODES.md`).
6. **Phase shape hint.** Typical sub-phase decomposition for
   this kind of work.

## Mixing stacks (fullstack work)

If the phase legitimately spans two stacks (e.g. backend +
frontend on a feature), keep one lens primary in `.dossier/LENS.md`
and reference the other in `PLAN.md`'s locked decisions. Don't
load both as `LENS.md` — pick the lens that owns the harder
gates.
