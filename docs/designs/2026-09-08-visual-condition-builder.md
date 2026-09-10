# Visual condition builder (Custom only)

**Date:** 2026-09-08
**Status:** Design approved, not yet implemented
**Prompted by:** leftover from the 2026-09-08 click-cost plan — “a visual condition builder” was out of scope there. The preset dropdown now restores Yes/No correctly; Custom is still a raw `var == 'yes'` field.

## The problem

A connection’s condition is almost always “if they answered X, go here.” Presets already do that in one click for this step’s Yes/No and option values. Custom exists for everything else — another question’s answer, *is not*, a number — and today that means typing the engine dialect.

That dialect is small (`ConditionEvaluator`: `variable == 'value'`, `!=`, numeric `>`, `>=`, `<`, `<=`). Typing it is the thinking click. The leftover `visual_condition_controller.js` already described the sentence, but it looks for `.step-item` from the deleted visual editor and is not rendered. It was deleted on 2026-09-10 with the other unmounted controllers; read its last version with `git show "$(git log -1 --format=%H --diff-filter=D -- app/javascript/controllers/visual_condition_controller.js)^:app/javascript/controllers/visual_condition_controller.js"`.

## Locked decisions

1. **Custom only.** Default / Yes / No / option labels / this-step numeric presets stay one click. Custom is no longer a text field.
2. **Any question in this workflow.** The sentence’s variable list is this step first (if it is a question with a name), then the others by title. Action output fields are out of this slice.
3. **Sentence only, with a safe fallback.** No raw `var == 'yes'` field in the happy path. An unparseable stored string is kept, not wiped.

## What you see

Choosing **Custom…** on a connection row replaces the text input with:

`[Already verified this contact? ▾]  [is ▾]  [Yes ▾]`

- **Variable** — question title. The stored condition still uses `variable_name`.
- **Operator** — *is* / *is not* for yes_no, options, text, date, file. A number variable gets: equals, does not equal, greater than, at least, less than, at most.
- **Value** — Yes/No select, option select, number input, or text input, matching that variable’s `answer_type`.

The hidden `condition` field and `step-transitions` JSON autosave do not change. The optional **Label** on the row stays.

A freshly chosen Custom does not write until the sentence has a variable **and** a value. Variable defaults to this step when it is a named question; otherwise the first list entry. Operator defaults to *is* (equals for numbers). An incomplete sentence leaves the hidden field as it was (blank on a new row, keep-as-written on an unparseable one).

The same markup is used when **Add Connection** injects a row in JS (`step_transitions_controller.js`). The two templates must not drift.

## Restore (first match wins)

Given a stored condition string:

1. Blank → **Default (no condition)** (already).
2. Matches a this-step Yes/No or option preset (meaning, not exact string — `conditionsMatch` already shipped) → that preset.
3. Parses as `variable operator value` in the engine dialect, but is not a this-step preset (other variable, `!=`, number) → **Custom**, sentence filled.
4. Does not parse → **Custom**, muted **Keep as written:** `the original string`. The hidden field is unchanged until the author changes a sentence control.

Picking a sentence value after (4) replaces the kept string with the new dialect form.

## Dialect written

Same strings the runner and imports already use:

| Sentence                         | Stored                      |
|----------------------------------|-----------------------------|
| *this* is Yes                    | `already_verified == 'yes'` |
| *this* is not Hosting            | `what != 'hosting_email'`   |
| Age is at least 18               | `age >= 18`                 |

Numeric comparisons are unquoted digits. String comparisons use single quotes. Yes/No values are lowercase `yes` / `no`.

## Variable list

Source: `Workflow#variables_with_metadata` (question steps with a `variable_name`: name, title, answer_type, options). Pass it into the transitions editor as JSON on the wrapper (no extra fetch). Do not change `GET /workflows/:id/variables` — that endpoint is names-only for `{{` autocomplete.

This step’s entry is first when the open step is a question with a name. Duplicate names keep the first question in list order.

A question with no `variable_name` yet does not appear. The author names it (already in the disclosure) and the list refreshes on the next panel render / autosave; do not live-scan the title field in this slice.

## What we will not do

- AND / OR. The engine cannot evaluate them.
- Action output fields as variables.
- Resurrect `visual_condition_controller.js` as the live controller. Steal parse/write patterns from its last version if useful (deleted 2026-09-10; see the command above); do not bring the file back.
- Diagram-as-editor, a second connection UI, or a raw-expression field in the happy path.
- Changing `ConditionEvaluator` or run semantics.

## Files (intended)

- Modify: `app/views/steps/_transitions_editor.html.erb` — Custom container becomes the sentence; wrapper carries variables JSON.
- Modify: `app/javascript/controllers/step_transitions_controller.js` — the injected row uses the same Custom markup.
- Modify: `app/javascript/controllers/condition_preset_controller.js` — show/hide the sentence, write the hidden field, restore rules 3–4.
- Modify: CSS for the sentence row (compact selects in the existing connection card). Prefer `steps.css` / a small block next to `.transition-item`, not new tokens. Do not revive the deleted `_visual_condition` rules beyond tokenised preview if a keep-as-written line needs type.
- Test: `test/system/workflow_builder_test.rb` (and an integration assertion that the editor HTML includes the sentence targets).

Do not add a new Stimulus controller unless `condition_preset_controller.js` cannot own the sentence without becoming two features. Prefer extending that controller: it already owns Custom vs preset.

## Tests

System, on the connection row (TDD, fail first):

1. Yes/No this-step preset still restores as **Yes**, not Custom. (Existing test stays green.)
2. Opening **Custom…** shows the three sentence controls and no `e.g., answer == "yes"` text field.
3. Custom on a later step: pick an earlier question by title, *is*, Yes → hidden condition is `earlier_var == 'yes'`.
4. Stored `other == 'yes'` on this step (other is a different question) opens Custom with that sentence filled, not a text field.
5. Stored `not a real condition` opens Custom with **Keep as written** visible; hidden field still that string.
6. **Add Connection** produces a row whose Custom path is the sentence, not the old text input.

Gate: `bin/rails test test/system/workflow_builder_test.rb` plus the existing preset restore tests. `test/integration/runner_shell_parity_test.rb` stays green (no run-path change).
