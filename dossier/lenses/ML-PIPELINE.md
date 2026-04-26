# Lens — ML pipeline

For training / eval / serving of ML models — PyTorch, JAX, sklearn,
HF Transformers, LLM eval harnesses — where determinism is hard,
eval-set scores are the contract, and regressions hide in averages.

## Surface vocabulary

- **Unit:** model artefact / checkpoint / eval-set entry / preprocessing step.
- **Output:** eval-set scores (per-task accuracy / F1 / BLEU / win-rate / token usage), confusion matrix, sample inferences, training curve, embedding space.
- **Contract:** scores within a regression band per eval set + fixture-determined sample inference + inference latency floor.

## Gate menu (select per phase)

These are gate candidates, not defaults. Copy only selected gates into
`PLAN.md` / `SPEC.md`; leave the rest as context.

- **Eval-set score band.** Per task: lower bound + upper bound. Meta-gate compares CI run vs band; out-of-band → fail. Bands ratchet up over time.
- **Per-slice score floor.** Aggregate score green can mask per-subgroup regression. Meta-gate asserts floor on every slice (gender / locale / topic / length-bucket).
- **Fixture-determined inference.** A frozen `(input, expected_output)` set; deterministic temp=0 inference must match exactly. Meta-gate diffs.
- **Inference latency floor.** P50 / P95 latency under N tokens; meta-gate asserts floor.
- **Determinism checks.** Same seed + same input → same output. Meta-gate runs twice, asserts equality.
- **No GPU non-determinism in eval.** Force `torch.use_deterministic_algorithms(True)` in eval harness; meta-gate on env vars.
- **Eval-set version pinned.** `eval_set.json` SHA committed; meta-gate asserts SHA matches loaded set.
- **No data leakage train↔eval.** Hash train + eval examples; meta-gate asserts disjoint.
- **Tokenizer / preprocessing version frozen.** Tokenizer SHA + version pinned; meta-gate.
- **Cost / token-usage band.** Per eval set: total tokens consumed; meta-gate asserts band.

## Output rebaseline specifics

| Step             | Command                                                               |
| ---------------- | --------------------------------------------------------------------- |
| Build            | `python -m build` / `pip install -e .`                                |
| Eval run         | `python -m evals.run --suite <name>` / `inspect eval ...`             |
| Unbaselined diff | `python -m evals.compare baseline.json current.json`                  |
| Read failures    | per-task delta listed; per-slice delta listed                         |
| Accept           | `python -m evals.update-baseline --suite <name>` (only when intended) |
| Sample diff      | `git diff fixtures/golden_inferences.jsonl`                           |

Goldens: `evals/<suite>/baseline.json` (scores), `fixtures/golden_inferences.jsonl` (deterministic samples).

## Probe specifics

- File: `_probe_<slug>_eval.py`
- Runner: `pytest -k _probe_<slug> -s` or `python _probe_<slug>_eval.py | tee /tmp/probe.txt`
- Dump shape: print 10 worst-loss examples, embedding cosine to known anchors, attention pattern, raw logits, tokenizer encoding.
- Common dump targets: per-example loss histogram, false-positive distribution by slice, model output before / after a preprocessing change, gradient norms during training.

## Stack footguns

- **Aggregate-score green hides slice regression.** Avg up by 1%, but worst-slice down 8%. → per-slice gate.
- **Eval set updated and baseline updated in same commit, no diff visible.** → freeze eval-set SHA separately; meta-gate on SHA pin.
- **Floating-point drift across hardware.** A100 vs H100 produces different logits. → pin hardware class in CI or use deterministic kernels.
- **Tokenizer bumped, baselines silently shift.** New token splits change scores by 0.5% across the board. → meta-gate on tokenizer version pin.
- **Train / eval contamination.** Eval examples leaked into train (paraphrase, near-duplicate). → hash + Bloom filter in setup; meta-gate.
- **`torch.no_grad()` missing in eval.** Memory blows up on long inputs. → meta-gate greps eval scripts.
- **`shuffle=True` in eval `DataLoader`.** Scores stable but golden inference samples drift run-to-run. → assert `shuffle=False` in eval.
- **Random seed set in main but not in worker.** Multi-worker `DataLoader` non-deterministic. → set per-worker seed.
- **`temperature=0` in API eval but provider replaces with epsilon.** Outputs drift slightly. → use `seed` parameter when supported; pin to a model snapshot.
- **Cost runaway in CI.** Eval suite calls paid API on every PR. → cache eval results by `(model, eval-set-sha, code-sha)`; meta-gate on cache lookup before run.
- **Class imbalance in eval.** Macro-F1 looks bad because eval slice is heavily skewed. → assert eval-set distribution on load.
- **Pretrained model version drift.** `from_pretrained("foo")` resolves to latest. → pin revision / SHA.

## Phase shape hint (optional)

Typical sub-phases for an ML phase:

- P0 — eval-set + tokenizer + model baseline freeze
- P1 — meta-gates (band, slice floor, determinism, cost, leakage)
- P2 — golden-inference fixture (deterministic samples)
- P3 — feature work (per-eval TDD rounds — set band → run → land)
- P4 — perf / latency / cost gate
- P5 — release / cut + closeout (describe model swap, latency / cost delta)
