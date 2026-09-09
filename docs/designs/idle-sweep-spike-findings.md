# Idle-sweep spike — findings

> **Status: all five recommendations shipped**, across `1997a75a`, `b51fc72c`,
> `06154415`, `992e8fd6` and `e673414e`. Kept on `main` because the shipped code
> and its tests point here for *why* — this is the record of what the probes found,
> not a plan waiting to be executed. The spike branch is `spike/idle-sweep`; the
> probe file `test/integration/idle_sweep_spike_test.rb` lives only there, and its
> findings are guarded on `main` by `scenario_terminal_status_test.rb`,
> `scenario_error_completion_test.rb` and `idle_scenario_sweep_test.rb`.
>
> Two things were found *after* the spike and are recorded in "What shipped" below:
> a third retention leak, and a rollup rule that would have corrupted history.

Branch `spike/idle-sweep`. Deliverable is this list.

`test/integration/idle_sweep_spike_test.rb` — 23 probes, all green *after* the
two-line fix in § 2. **Full suite: 2170 runs, 0 failures, 0 errors** with that fix
applied.

Scope: answer "given a non-terminal Scenario row, has the RUN it belongs to been
idle for 24h?" Nothing answers that today — `timeout` is in the enum with no
writer, and both cleanup scopes require `terminal` **and** a `completed_at`, so
every abandoned run is immortal (52% of dev rows: 63 of 120).

This is the fifth reader of run topology, after `run_origin`, `run_head`,
`runner_step_redirect` and `stop!`. Per `handoff-spike-findings.md` the previous
four were each wrong in a different way. So the probes test three candidate
clocks against six topologies rather than asserting a design.

---

## 1. The finding that changes the plan: `run_head` is the wrong clock

**The agreed design said key idleness off `run_head.updated_at`. That would settle
live runs.**

`run_head` alternates `root_scenario` and `handed_off_to`. **Neither link descends
into an ordinary sub-flow child.** So for a parent parked in `awaiting_subflow`
with an agent actively working inside its child:

- `parent.run_head == parent` — the parked parent is its own head;
- `belongs_to :parent_scenario` has no `touch: true`, so the parent's `updated_at`
  froze when it parked;
- therefore `run_head.updated_at` reports a **live** run as idle.

`P2b` asserts exactly this. It is not a bug in `run_head` — the method answers
"which frame is the run on", and for a parked parent the honest answer *is* the
parent, because the run is suspended there pending a return. It is the wrong
question for a clock.

**The clock is `max(updated_at)` across every frame of the run.** The spike's
`run_frames` primitive seeds from `run_origin` and closes over **both** links in
**both** directions (`child_scenarios`, `handed_off_from_id`, `parent_scenario`,
`handed_off_from`). `P1a` shows it reaches both halves of a handoff from either
end and that the two ends agree on the frame set.

`P1b` records the gap this closes: `root_scenario.unfinished_descendants` — the
walk `stop!` uses — **cannot see a handed-to run**, because a handed-to run has no
`parent_scenario_id` by design.

> Do not "fix" this with `touch: true` on the association. Every step answered
> inside a sub-flow would write N ancestor rows and take N optimistic locks,
> putting `StaleObjectError` into the runner's hot path to save a join — and it
> still would not reach handoff chains, which have no parent link at all.

## 2. A live bug the sweep would have amplified

**`Scenario#terminal?` returns `false` for `timed_out` and `errored`.**

Rails enum *readers return the label*, not the DB value. The enum maps
`timed_out → "timeout"` and `errored → "error"`, but `TERMINAL_STATUSES` holds the
DB values. So `status` reads `"timed_out"`, which is not in the list.

This affects **exactly** the two members where label ≠ value. `completed` and
`stopped` are identical in both, which is why this read correctly for years.
`scenario_handoff_termination_test.rb:46` half-noticed — *"the only
TERMINAL_STATUSES member that reads correctly"* — and did not chase it.

**This is live today, not latent.** `status = 'error'` is written in two places:
`Scenario#count_iteration!` (MAX_ITERATIONS exceeded) and
`ScenarioStepProcessor#process_subflow_step` (sub-flow target missing).

The SQL scope compares DB values and is correct, so **Ruby and SQL disagree about
the same row** (`P8b`). Confirmed consequences, each with a probe:

| Probe | Consequence |
|---|---|
| `P8c` | `stop_frame!`'s `return if terminal?` does not fire, so an errored run's outcome is **overwritten** with `abandoned` — the error record is destroyed |
| `P8d` | `live_handed_off_to`'s `reject(&:terminal?)` keeps an errored branch, so `run_head` reports a **dead frame as live** |
| `P8e` | the runner renders an **answerable card** on a run that died on the iteration limit |
| `P6c` | same, for a swept `timeout` run — at ~500 runs/day this goes from rare to routine |

**The fix is two lines, and the suite is green on it.**

```ruby
def terminal?
  TERMINAL_STATUSES.include?(self.class.statuses[status])  # label -> DB value
end

def complete?
  return true if terminal?   # was: enumerated completed?/stopped? then fell through
  ...
end
```

`terminal?` translates rather than duplicating the list, because the SQL scope
genuinely needs the DB values. `complete?` gaining `return true if terminal?` is
the Q11(b) decision, and it is **load-bearing, not belt-and-braces**: fixing
`terminal?` alone leaves `complete?` falling through to
`current_node_uuid.nil? && !active?`, so the runner still offers an answerable
card. Nulling `current_node_uuid` in the sweep also masks it — that is the
fragile version (`P6b`), where two columns happening to line up is what makes it
work.

**Ship this ahead of the sweep, on its own.** It fixes a live bug for errored
runs, and the sweep is unsafe without it.

## 3. Settling is mostly already solved

`stop!` on the deepest live frame settles the parent chain correctly (`P3a`), is
idempotent and does not restamp an earned outcome (`P3b`), and earlier handoff
links are already terminal because `hand_off!` settled them (`P7c` — every frame
of the run ends up terminal).

What is needed is a `time_out!` sibling of `stop_frame!`: `status: "timeout"`,
`outcome: "abandoned"`, `current_node_uuid: nil`, and
`completed_at = <the run's last activity>`. `P7a` confirms that combination is a
valid record and reads as `complete?`; `P7b` confirms it lands in the existing
`stale_live` scope, which is what lets the current retention job collect it.

`P3c` confirms the run's last activity is available at settle time, which is what
Q16 needs — `completed_at = updated_at`, not `Time.current`.

## 4. Locking: the batch must rescue per run

`P5a`: settling a frame while an agent holds a stale copy raises
`StaleObjectError`. A sweep that settles many runs in one pass must rescue **per
run** and continue — one contended run must not abort the batch. Note the
existing precedent: `process_subflow_step` and `process_subflow_completion` both
rescue `StaleObjectError` and log a WARN.

## 5. Enumeration

`P4a`: the candidate set is `where(status: %w[active awaiting_subflow])`, grouped
by `run_origin.id` so a multi-frame run is swept once rather than once per frame.
Bounded by the number of non-terminal rows, so the backfill is the largest pass it
will ever do.

## 6. Residual, minor, pre-existing

When **every** handoff branch is terminal, `live_handed_off_to`'s
`|| branches.last` fallback picks the highest id — which can be an errored branch
over a completed one, so results show the error rather than the completion. Not
created by the sweep. Recorded so the tie-break becomes a decision rather than an
accident.

## What the plan should say

1. **Fix `terminal?` / `complete?` first, alone.** Live bug; two lines; suite green.
2. **The sweep's clock is `max(updated_at)` over `run_frames`**, not
   `run_head.updated_at`. `run_frames` is a new primitive and should be named and
   commented as the sixth reader of run topology.
3. Settle via a `time_out!` sibling of `stop_frame!`, driven from the deepest live
   frame so the existing parent-chain cascade does the work.
4. Rescue `StaleObjectError` per run.
5. Backfill and ongoing both stamp `completed_at` from the run's last activity.

---

## What shipped, and what the spike did not see

All five items above shipped as written. Two more turned up afterwards, both of
the same family — a value written without the bookkeeping the rest of the system
assumes goes with it.

**A third retention leak (`b51fc72c`).** Found by driving `count_iteration!` for
real rather than trusting a fixture. Both writers of `status = 'error'` set the
status and nothing else, so an errored run had a NULL `completed_at` — and
`NULL < date` is never true in SQL, so neither cleanup scope could ever match it.
Errored runs were immortal too, by a different route than abandoned ones, and
invisible for the same reason: the rows read as terminal everywhere except the
retention scopes. Both writers now call `record_completion("error")`.

**The rollup day rule (`e673414e`).** Rollups key on `started_at`; cleanup keys on
`completed_at`. So a day's runs are deleted across several nights, and the obvious
rule — re-roll every day that still has raw rows — recomputes a draining day from
its survivors, undercounts, and freezes at the wrong number. It fails exactly at
the horizon the rollup exists to protect. A day is therefore rolled only while it
is still moving: no rows yet, or inside `REFRESH_DAYS`. The guard is
`scenario_rollup_builder_test.rb` "a closed day is not recomputed as its runs are
deleted", verified to fail against the naive rule.

**What this says about the method.** The spike found the topology traps, which is
what it was for. It did not find either of these, because both live at a seam it
never crossed — one in a writer it never ran, one in a table that did not exist
yet. Both were caught the same way the spike caught its own: by running the real
code against real data and reading what came back, rather than reasoning about
what should happen.
