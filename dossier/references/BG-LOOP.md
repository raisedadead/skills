# Background command + ScheduleWakeup loop

Any command that takes >30s wall clock runs in the background.
Pacing comes from `ScheduleWakeup`, not `sleep`. The runtime
delivers a `<task-notification>` on completion.

## Why not `sleep`

- Long leading `sleep` is blocked by the harness.
- `sleep`-loops burn the prompt cache (5-min TTL): every wakeup
  reads the full conversation context uncached.
- `ScheduleWakeup` lets the runtime deliver a notification on
  actual completion. No wasted polls.

## Cache TTL math

The Anthropic prompt cache TTL is 5 minutes. So:

| `delaySeconds` | Cost                      | When to use                              |
| -------------- | ------------------------- | ---------------------------------------- |
| 60-270         | Cheap (cache warm)        | Active work — short builds, narrow runs. |
| 300-1200       | **Worst-of-both — avoid** | Pays cache miss without amortising it.   |
| 1200-3600      | Pays miss, amortises      | Genuinely idle waits.                    |

If tempted to "wait 5 minutes": drop to 270s (stay in cache) or
commit to 1200s+ (one miss buys a much longer wait).

## Pattern

```
# Step 1 — kick off long command
Bash({
  command: "pnpm exec playwright test --update-snapshots 2>&1 | tail -3",
  description: "Full visual rebaseline after layout fix",
  run_in_background: true
})
→ "Command running in background with ID: <task-id>.
   Output is being written to: /private/tmp/.../tasks/<task-id>.output"

# Step 2 — schedule pacing
ScheduleWakeup({
  delaySeconds: 300,
  reason: "Full visual rebaseline after layout fix",
  prompt: "<<autonomous-loop-dynamic>>"
})
→ "Next wakeup scheduled for HH:MM:SS (in 281s)."

# Step 3 — runtime delivers notification on completion
<task-notification>
  <task-id>...</task-id>
  <output-file>/private/tmp/.../tasks/<task-id>.output</output-file>
  <status>completed</status>
  <summary>Background command "..." completed (exit code 0)</summary>
</task-notification>

# Step 4 — read tail, decide next action
Bash({
  command: "tail -5 /private/tmp/.../tasks/<task-id>.output && git status --short",
  description: "Rebaseline result + diff"
})

# Step 5 — commit + update task list
Bash: git add ... && git commit -m "..."
TaskUpdate({ taskId: <n>, status: "completed" })
```

## delaySeconds choices (observed actuals across stacks)

- 60-120s — short builds, narrow runs (single test, single route, single file).
- 120-180s — full unit suite + coverage, full type-check, full schema regen, library bundle.
- 180-300s — full e2e / visual / contract suite, full terraform plan against large state, dbt full-refresh on staging, fresh container build with cache miss.
- 300-1800s — long migrations, ML eval-set runs, soak tests. Pay the cache miss; plan to do other work meanwhile.

## The `<<autonomous-loop-dynamic>>` sentinel

Always pass this string verbatim as `prompt`. The runtime resolves
it to the full autonomous-loop instructions at fire time so the
loop self-continues with the same context.

There is also a `<<autonomous-loop>>` sentinel for `CronCreate`
mode. **`ScheduleWakeup` always uses `-dynamic`.** Do not confuse
the two.

## What never happens

- ❌ `sleep` in shell.
- ❌ Polling (re-running `tail` on a known background task).
- ❌ Re-scheduling an already-scheduled wakeup.
- ❌ Killing a background task that is still running.
- ❌ Two builds in parallel against the same output (e.g. `pnpm build` while another writes `dist/`; two `terraform apply` against the same state; two migrations against the same DB; two model trainings to the same checkpoint dir). The artefact is exclusive — serialise.

## When to omit the next wakeup

Omitting `ScheduleWakeup` ends the loop. Do this once at phase
close after the final commit lands and `TaskList` shows zero
in-flight.
