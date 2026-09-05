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

---

# Wave 2, replanned from the spike

This replaces `workflow-handoff.md` §T as the build order. §T's *site list* was
largely accurate — its sequencing was not, and two of its items turned out to be
one item while a third was not needed at all.

**What is already built on `spike/handoff` and is keepable as-is:** the two
columns, `run_origin`/`run_head` with their tests, the `GraphHashBuilder` field,
the two `GraphValidator` rules, the `descend` fallback, the `SubflowValidator`
depth exemption, and the `runner_step_redirect` forward branch. That is roughly
half of §T, verified. The spike's one throwaway is the ancestor-termination loop
in `scenario_step_processor.rb`, which works but is written as a `while` over
`update_columns` and belongs on `Scenario` with proper locking.

## Order

**1. Make the ancestor termination real.** The spike proves the rule — a handoff
ends every frame waiting on it — but implements it with `update_columns`, which
skips validations, callbacks and `lock_version`. Move it to a `Scenario` method
beside `stop!`, which already does a cascade correctly and is the model to follow.

**Correction to an earlier draft of this section:** it called the status an open
data-model decision. It is not — `workflow-handoff.md` §T item 3 already decided
it, and the reasoning holds: `status: "completed"` (the only member of
`TERMINAL_STATUSES` that reads correctly, making `terminal?` true so
`stop_frame!` cannot overwrite the outcome, `parked?` false, and both cleanup
scopes applicable) with `outcome: "transferred"`, `current_node_uuid: nil`,
`completed_at: Time.current`. Putting "transferred" on `outcome` rather than
`status` is what keeps reporting honest — a handed-off run is not a completed
one, and `outcome` is the column that says how a run ended.

**What the spike actually does is a subset of that**, and the gap is the work:
it sets `status` and `completed_at` but neither `outcome` nor
`current_node_uuid: nil`. `Scenario::OUTCOMES` (`:75`) must gain `"transferred"`
first — verified: `update!` with it is refused today by the inclusion validation.

**2. The thread splice (SC 2).** The single biggest user-visible gap, and the
feature's whole purpose. `run_origin` exists for this. The head's
`execution_path` is empty and the origin holds the entries, so
`runner_thread_entries` must walk origin → head and concatenate, without adding
indentation at the boundary — a handoff is not a nesting level. Do this second
because it is what makes a handoff *feel* like one run, and because every
remaining item is easier to judge once a real transcript renders.

**3. Settle Open Q2 and route the header through one reader.** The app currently
answers the title-flip question both ways in a single session. Once decided,
`runner_shell.rb:82` and `:165` and `player_controller.rb:55` all take
`run_origin.workflow` (or `run_head.workflow`) instead of `root_workflow`. The
embed bug falls out here: a handed-to workflow has no share token, so
`embeddable?` is false and an embedded share-link run loses embed mode at the
boundary.

**4. Round-trip (§R items 9-10).** The published schema forbids the exact shape
this feature emits: `ImportSchemaGenerator` gives every non-resolve step a
`transitions` property with `minItems: 1`, and a handoff step has none. Export,
schema, and `StrictImportValidator` move together or a handoff workflow exports
to a file the app refuses — the same class of defect as the two round-trip
exceptions already documented in AGENTS.md.

**5. `StepFieldMap` + `StepSerializer` carry `sub_flow_returns` (SC 9).** Do not
leave this last despite its position here: a field missing from the serializer is
**erased on version restore**, silently. The map-driven test is the guard. It is
listed at 5 only because it is mechanical once 4 has settled the field's name in
the export document.

**6. The builder UI.** A checkbox on the sub-flow step editor, plus the step row
and flow diagram rendering a handoff as terminal (`Step#terminal?` is
`transitions.empty?`, and `condition_summary` prints "Terminal" only for
`Steps::Resolve`).

Checked, so this is smaller than it looked: the sub-flow panel does **not** share
the Form fields' no-autosave P2. `_sub_flow.html.erb:11` already carries
`change->inline-autosave#schedule` on its select, so the pattern for a new
checkbox is right there — it just has to be given its own `data-action`, since
that defect is precisely a missing one.

## Dropped from §T

- **Item 6 (`WorkflowHealthCheck` `add_resolve_after`)** — not needed. The panel
  derives `terminal_not_resolve` from `GraphValidator`, so fixing the validator
  fixed the panel. SC 8 passes with no health-check change.
- **Item 12a's "new Outcome status"** — not needed for a working handoff. The
  existing `awaiting_subflow` outcome plus a `descend` that also looks at
  `handed_off_to` is enough, and it is a smaller change. Revisit only if the
  thread splice needs to distinguish the two at render time.

## What the spike did not touch, and what it would cost to find out

Publish-time handoff cycle refusal is confirmed working (SC 5). Untested:
concurrent runs over a handoff boundary under optimistic locking, and anonymous
share-link runs crossing a boundary.

**One verified constraint on decision 1.** `Scenario#unfinished_descendants`
(`:260`) recurses through `child_scenarios` only, so it cannot see across a
handoff — checked on the real pair: `625.unfinished_descendants` is `[]` while
626 is the live run. `stop!` is built on it, so "stop this run" reaches only one
side of a boundary.

That is **not** a live leak today, and an earlier draft of this section
overstated it as one: the spike terminates every waiting ancestor eagerly, so
nothing non-terminal is ever left behind a boundary. The real content is that it
constrains decision 1 — if ancestor termination is done any way that leaves those
frames non-terminal (a "handed off" status rather than a terminal one), `stop!`
and the retention scopes silently stop reaching them. Whatever status is chosen
must either be terminal, or `unfinished_descendants` must learn to cross the
handoff link.
