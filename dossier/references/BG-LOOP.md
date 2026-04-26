# Long command loop

Any command that takes >30s wall clock uses the selected runtime
adapter. Claude Code uses background Bash + `ScheduleWakeup`; Codex
uses command sessions and polling; OpenCode uses its native shell/session
mechanism. Never use shell `sleep` loops.

## Why not `sleep`

- Long leading `sleep` is blocked by the harness.
- `sleep`-loops burn the prompt cache (5-min TTL): every wakeup
  reads the full conversation context uncached.
- Runtime wait/resume primitives let the agent continue without burning
  cycles on shell sleeps.

## Claude Code cache TTL math

Claude/Anthropic prompt cache TTL is 5 minutes. For Claude Code
`ScheduleWakeup`:

| `delaySeconds` | Cost                      | When to use                              |
| -------------- | ------------------------- | ---------------------------------------- |
| 60-270         | Cheap (cache warm)        | Active work — short builds, narrow runs. |
| 300-1200       | **Worst-of-both — avoid** | Pays cache miss without amortising it.   |
| 1200-3600      | Pays miss, amortises      | Genuinely idle waits.                    |

If tempted to "wait 5 minutes" in Claude Code: drop to 270s (stay in
cache) or commit to 1200s+ (one miss buys a much longer wait). Other
runtimes should follow their adapter's session economics.

## Pattern

```
# Step 1 - kick off long command
long_command({
  command: "pnpm exec playwright test --update-snapshots 2>&1 | tail -3",
  description: "Full visual rebaseline after layout fix"
})
-> runtime returns a task/session id and output location

# Step 2 - arrange continuation
resume_after_wait({
  delaySeconds: 300,
  reason: "Full visual rebaseline after layout fix"
})
-> runtime-specific wait/resume

# Step 3 - runtime reports completion or agent polls session

# Step 4 - read tail, decide next action
run_command({
  command: "tail -5 /private/tmp/.../tasks/<task-id>.output && git status --short",
  description: "Rebaseline result + diff"
})

# Step 5 - commit + update task list
commit_paths(...)
task_done
```

## delaySeconds choices (observed actuals across stacks)

- 60-120s — short builds, narrow runs (single test, single route, single file).
- 120-180s — full unit suite + coverage, full type-check, full schema regen, library bundle.
- 180-300s — full e2e / visual / contract suite, full terraform plan against large state, dbt full-refresh on staging, fresh container build with cache miss.
- 300-1800s — long migrations, ML eval-set runs, soak tests. Pay the cache miss; plan to do other work meanwhile.

## Claude Code sentinel

In Claude Code, always pass `<<autonomous-loop-dynamic>>` verbatim as
the `ScheduleWakeup` prompt. The runtime resolves
it to the full autonomous-loop instructions at fire time so the
loop self-continues with the same context.

There is also a `<<autonomous-loop>>` sentinel for `CronCreate`
mode. **`ScheduleWakeup` always uses `-dynamic`.** Do not confuse
the two.

## What never happens

- ❌ `sleep` in shell.
- ❌ Wasteful polling when the runtime can notify / resume.
- ❌ Re-scheduling an already-scheduled wakeup/session wait.
- ❌ Killing a background task that is still running.
- ❌ Two builds in parallel against the same output (e.g. `pnpm build` while another writes `dist/`; two `terraform apply` against the same state; two migrations against the same DB; two model trainings to the same checkpoint dir). The artefact is exclusive — serialise.

## When to omit the next wakeup

Omit the next resume/wait once the phase is closed, the final task is
done, and `task_list` shows zero in-flight work.
