# Handoff spike — findings

Branch `spike/handoff`, commit `ec7da545`. **Not shippable.** The deliverable is
this list; the Wave 2 plan should be rewritten from it rather than from
`workflow-handoff.md` §T alone.

Scope: two columns, a fork at the sub-flow spawn site, one change in
`ScenarioSettler#descend`, and the minimum graph-validation work needed to make
a handoff workflow saveable at all. One handoff runs end to end.

## Result

`test/integration/handoff_spike_test.rb` — 6 tests, **4 pass, 2 fail**, and the
two failures are both already-listed items, not discoveries.

**The existing suite is unchanged: 1948 runs, 0 regressions.** `default: true`
on `sub_flow_returns` did its job — every existing sub-flow still returns.

## The finding that changes the plan

**A handoff is not "this frame ends". It is "every frame waiting on this one
ends".**

`A → sub-flow B → handoff C` left A in `awaiting_subflow` and `parked?`, because
`parked?` is `awaiting_subflow? && active_child_scenario.nil?` and B — now
`completed` — is no longer active. A then offers a Resume that calls
`process_subflow_completion`, which selects
`child_scenarios.where(status: 'completed').order(updated_at: :desc).first`,
finds B, and **resurrects A**. That is the `scenario.rb:314` failure the design
doc found in two separate review rounds, reached here from a third direction.

What matters for the plan: **nulling the handed-to scenario's
`parent_scenario_id` does not touch this.** The damage is on the *ancestor's*
side, not the handed-to side. The doc's framing — four readers that misread the
parent FK — is right about the readers but understates the fix: the ancestor
chain has to be terminated at handoff time, which the spike does crudely in
`scenario_step_processor.rb`.

**Consequence for `run_origin` (§T item 13a): it is a real primitive, and the
spike strengthens the case.** Once ancestors are terminated, the run's history
spans a chain that the parent FK no longer describes at all — A's steps are only
reachable by walking `handed_off_from` from C to B and then `parent_scenario`
from B to A. That is exactly the alternating walk 13a specifies, and it is now
load-bearing rather than tidy-up. Build it before the rest of Wave 2.

## Readers that misbehaved

| Reader | What broke | Status |
|---|---|---|
| `GraphValidator#validate_terminals` + `validate_escapable` | A handoff workflow **could not be saved at all** — `terminal_not_resolve` + `no_path_to_resolve`. Blocks every other test. | doc §T 4-5; fixed in spike |
| `GraphHashBuilder#call` | Emits only id/type/title/transitions, so the validator is blind to the flag. Must be fixed first or nothing downstream can see it. | doc §T 4; fixed in spike |
| `ScenarioSettler#descend` | `active_child_scenario` asks the parent FK; a handed-to run has none, so it returned nil and the run **silently ended on the handoff node**. | doc's table row 2; fixed in spike |
| `Scenario#parked?` + `process_subflow_completion` | The §N ancestor resurrection above. | doc's table row 3, but the fix is not the one implied |
| `RunnerShell` GET redirect | SC4b still red: a GET on the abandoned half does not forward to the live run. | **not yet fixed** |
| `SubflowValidator#calculate_max_depth` | Counts handoff edges toward `MAX_DEPTH`, so a flat 13-hop chain is refused for nesting that does not exist. Live because `4ccee4fd` restored the import refusal. | Wave 1 item 4; **not yet fixed** |

`WorkflowHealthCheck` (SC 8) passed once `GraphValidator` stopped emitting
`terminal_not_resolve` — the doc predicted a separate fix there and it was not
needed, because the health panel derives that issue from the validator.

## A finding about the tests, not the code

**SC4a and SC4b passed with zero handoff implemented.** A non-returning sub_flow
still descended like an ordinary one, so the run *did* land on the target's first
step — as a child. Both tests were asserting something true of plain sub-flows.

The assertions that actually separate a tail call from a call are: the handed-to
scenario has **no** `parent_scenario_id`, it carries `handed_off_from_id`, and
the source is `terminal?`. Without those three, this suite would have green-lit
exactly the no-op feature the doc says both earlier drafts shipped.

Worth carrying into Wave 2: for this feature, "the run reached the next workflow"
is not evidence of anything. Only "and nobody is waiting behind it" is.

## Round 2 — `run_origin`, `run_head`, and a real run in a browser

Both primitives are built and pinned (`test/models/scenario_run_origin_test.rb`,
10 tests). All 7 handoff tests pass. **Full suite 1965 runs / 0 failures,
rubocop clean.**

`run_origin` walks backward alternating both links; `run_head` walks forward to
the chain tail. Both guard against cyclic data rather than trusting it. The two
remaining couplings closed with them:

- `RunnerShell#runner_step_redirect` got the forward branch. Verified in a
  browser: `GET /scenarios/625/step` on the abandoned half now 302s to
  `/scenarios/626/step`, the live run.
- `SubflowValidator` stops counting handoff edges toward `MAX_DEPTH`, and a new
  test asserts a handoff **cycle** is still caught — exempting handoffs from
  depth must not exempt them from cycles.

### What a real run in the browser found that the tests did not

A two-workflow handoff (HO Diagnose → HO Escalate) run end to end:

1. **The handoff itself works.** Answering the last question renders HO
   Escalate's first question in the same POST. Source is `completed`/terminal,
   target has no parent and carries `handed_off_from_id`.
2. **SC 3 confirmed free:** the target inherits `results` — `restarted` is
   readable after the boundary.
3. **SC 2 fails, and it is the feature's own purpose.** The transcript is
   **truncated at the boundary** — nothing before the handoff renders. Cause is
   exact: the head's `execution_path` is empty (0 entries) while the origin holds
   all of them (2), and the thread renderer reaches for `root_scenario`, which
   for a handed-to run is itself. **This is `run_origin`'s second caller and the
   reason it exists.**
4. **The header flips depending on how you arrived.** The POST response showed
   "HO Diagnose"; a fresh GET of the same run shows "HO Escalate", because
   `runner_shell.rb` uses `root_workflow`. Open Q2's title-flip question is not
   theoretical — today the app answers it both ways in one session. Pick one and
   route it through `run_origin`.

## What is still unknown

Closed since round 1: SC 2 is now *diagnosed* (above) though not fixed, SC 3 and
SC 5 are confirmed working, and SC 4/4a/4b are green.

Still untouched: the thread splice itself (SC 2's fix), export/import round-trip
of a handoff (SC 6 — and §R items 9-10, since the published schema currently
forbids a transition-less non-resolve step), the embed/share path
(`player_controller.rb:55`), the builder UI for setting the flag, and
`StepFieldMap`/`StepSerializer` carrying `sub_flow_returns` through publish and
version restore (SC 9) — that last one is the field-erasure trap, so it must not
be left to the end.
