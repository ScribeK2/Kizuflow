# Visual condition builder (Custom only) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Custom raw `var == 'yes'` field with a three-control sentence over this workflow’s questions, without touching Yes/No/option presets.

**Architecture:** `condition_preset_controller.js` already owns Custom vs preset. Extend it: Custom shows a sentence (variable / operator / value) that writes the existing `ConditionEvaluator` dialect into the same hidden field. Variable metadata is `Workflow#variables_with_metadata`, JSON on the transitions wrapper — no extra fetch. Do not wire `visual_condition_controller.js`.

**Tech Stack:** Rails 8.1, Stimulus, Hotwire, Minitest + Capybara system tests, vanilla CSS

**Spec:** `docs/designs/2026-09-08-visual-condition-builder.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `app/helpers/workflows_helper.rb` | `condition_sentence_variables(workflow, step)` — this step first |
| `app/views/steps/_transitions_editor.html.erb` | Sentence markup; variables JSON on the wrapper |
| `app/javascript/controllers/step_transitions_controller.js` | Injected row uses the same sentence markup; copies variables JSON |
| `app/javascript/controllers/condition_preset_controller.js` | Show/hide sentence, write dialect, restore rules 3–4 |
| `app/assets/stylesheets/workflows.css` | Compact sentence row next to `.transition-item__condition` |
| `test/helpers/workflows_helper_test.rb` | Variable order |
| `test/controllers/steps_panel_edit_stimulus_values_test.rb` | HTML contract (targets + JSON attribute) |
| `test/system/workflow_builder_test.rb` | Spec tests 2–6; update existing Custom selectors |

Do not add a second Stimulus controller. Do not change `ConditionEvaluator`, `GET /workflows/:id/variables`, or run semantics.

**Representability rule (spec restore 3 vs 4):** a parsed condition whose value cannot be shown in the value control for that variable’s `answer_type` (e.g. `verified == 'maybe'` on a yes_no question) is **Keep as written**, not a sentence that would snap to Yes. Same as unparseable: hidden field unchanged until the author edits a sentence control.

---

### Task 1: This-step-first variable list

**Files:**
- Modify: `app/helpers/workflows_helper.rb`
- Modify: `test/helpers/workflows_helper_test.rb`

- [ ] **Step 1: Write the failing helper test**

Add to `WorkflowsHelperTest`:

```ruby
test "condition_sentence_variables puts the open question first" do
  user = User.create!(
    email: "csv-#{SecureRandom.hex(4)}@example.com",
    password: "password123!",
    password_confirmation: "password123!",
    role: "editor"
  )
  workflow = Workflow.create!(title: "Vars", user: user)
  first = Steps::Question.create!(
    workflow: workflow, position: 0, title: "Already verified?",
    question: "Already?", answer_type: "yes_no", variable_name: "already_verified"
  )
  later = Steps::Question.create!(
    workflow: workflow, position: 1, title: "Did it work?",
    question: "Work?", answer_type: "yes_no", variable_name: "verified"
  )
  Steps::Resolve.create!(
    workflow: workflow, position: 2, title: "Done", resolution_type: "success"
  )

  names = condition_sentence_variables(workflow, later).map { |v| v[:name] }
  assert_equal %w[verified already_verified], names
end

test "condition_sentence_variables is unchanged for a non-question step" do
  user = User.create!(
    email: "csv2-#{SecureRandom.hex(4)}@example.com",
    password: "password123!",
    password_confirmation: "password123!",
    role: "editor"
  )
  workflow = Workflow.create!(title: "Vars2", user: user)
  Steps::Question.create!(
    workflow: workflow, position: 0, title: "Q",
    question: "Q?", answer_type: "yes_no", variable_name: "q"
  )
  action = Steps::Action.create!(workflow: workflow, position: 1, title: "Do it")

  names = condition_sentence_variables(workflow, action).map { |v| v[:name] }
  assert_equal %w[q], names
end
```

- [ ] **Step 2: Run it — expect fail** (method missing)

```
bin/rails test test/helpers/workflows_helper_test.rb -n "/condition_sentence_variables/"
```

- [ ] **Step 3: Implement**

In `workflows_helper.rb`, next to `variable_options_for_select`:

```ruby
def condition_sentence_variables(workflow, current_step)
  vars = workflow.variables_with_metadata
  return vars unless current_step.is_a?(Steps::Question) && current_step.variable_name.present?

  name = current_step.variable_name
  this, others = vars.partition { |var| var[:name] == name }
  this + others
end
```

- [ ] **Step 4: Run tests — expect pass**

```
bin/rails test test/helpers/workflows_helper_test.rb -n "/condition_sentence_variables/"
```

- [ ] **Step 5: Commit**

```
git add app/helpers/workflows_helper.rb test/helpers/workflows_helper_test.rb
git commit -m "$(cat <<'EOF'
Put the open question first in the condition sentence variable list

Custom will pick any question in the workflow. This step has to lead
or the author is staring at someone else's title.
EOF
)"
```

---

### Task 2: Failing HTML contract

**Files:**
- Modify: `test/controllers/steps_panel_edit_stimulus_values_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
test "the transitions editor carries sentence targets and variables JSON, not a raw custom field" do
  earlier = Steps::Question.create!(
    workflow: @workflow, position: 0, title: "Already verified?",
    question: "Already?", answer_type: "yes_no", variable_name: "already_verified"
  )
  later = Steps::Question.create!(
    workflow: @workflow, position: 1, title: "Did it work?",
    question: "Work?", answer_type: "yes_no", variable_name: "verified"
  )
  Transition.create!(step: later, target_step: earlier, position: 0, condition: "already_verified == 'yes'")

  get panel_edit_workflow_step_path(@workflow, later)

  assert_response :success
  assert_select "[data-condition-preset-target='sentenceContainer']"
  assert_select "[data-condition-preset-target='sentenceVariable']"
  assert_select "[data-condition-preset-target='sentenceOperator']"
  assert_select "[data-condition-preset-target='sentenceValue']"
  assert_select "[data-condition-preset-target='keepAsWritten']"
  assert_select "[data-condition-preset-target='customInput']", count: 0
  assert_no_match "e.g., answer ==", response.body

  json = ERB::Util.html_escape(condition_sentence_variables(@workflow, later).to_json)
  assert_includes response.body, %(data-condition-preset-variables-value="#{json}")
end
```

Include `WorkflowsHelper` in the test class if `condition_sentence_variables` is not already available (ActionDispatch::IntegrationTest does not include it by default). Either include the helper or inline the expected JSON from `variables_with_metadata` with `verified` first:

```ruby
expected = @workflow.variables_with_metadata
this, others = expected.partition { |v| v[:name] == "verified" }
json = ERB::Util.html_escape((this + others).to_json)
```

- [ ] **Step 2: Run it — expect fail** (selector count 0)

```
bin/rails test test/controllers/steps_panel_edit_stimulus_values_test.rb -n "/sentence targets/"
```

- [ ] **Step 3: Commit the failing test only**

```
git add test/controllers/steps_panel_edit_stimulus_values_test.rb
git commit -m "$(cat <<'EOF'
Fail: the transitions editor must ship a sentence, not a raw custom field
EOF
)"
```

---

### Task 3: ERB sentence markup

**Files:**
- Modify: `app/views/steps/_transitions_editor.html.erb`

- [ ] **Step 1: Replace the custom text field and hang variables JSON on each condition-preset wrapper**

On the `step-transitions` root, add:

```erb
data-step-transitions-variables-value="<%= ERB::Util.html_escape(condition_sentence_variables(workflow, step).to_json) %>"
```

On each `data-controller="condition-preset"` div, add:

```erb
data-condition-preset-variables-value="<%= ERB::Util.html_escape(condition_sentence_variables(workflow, step).to_json) %>"
```

Replace the `customContainer` block with:

```erb
<div data-condition-preset-target="sentenceContainer" class="is-hidden condition-sentence">
  <select data-condition-preset-target="sentenceVariable"
          data-action="change->condition-preset#handleSentenceChange"
          class="form-select condition-sentence__variable"
          aria-label="Condition variable"
          title="Which answer this connection checks">
  </select>
  <select data-condition-preset-target="sentenceOperator"
          data-action="change->condition-preset#handleSentenceChange"
          class="form-select condition-sentence__operator"
          aria-label="Condition operator"
          title="How to compare">
  </select>
  <span data-condition-preset-target="sentenceValue" class="condition-sentence__value"></span>
  <p data-condition-preset-target="keepAsWritten" class="condition-sentence__kept is-hidden" hidden></p>
</div>
```

Do **not** leave `customInput` / `customContainer` / the `e.g., answer == "yes"` placeholder.

Update the tip:

```erb
<p class="form-hint mt-2">
  Select a preset, or choose "Custom..." to build "when this answer is …".
</p>
```

- [ ] **Step 2: Run the HTML contract — expect pass**

```
bin/rails test test/controllers/steps_panel_edit_stimulus_values_test.rb -n "/sentence targets/"
```

- [ ] **Step 3: Commit**

```
git add app/views/steps/_transitions_editor.html.erb test/controllers/steps_panel_edit_stimulus_values_test.rb
git commit -m "$(cat <<'EOF'
Render the condition sentence in the transitions editor

Custom is three controls and a keep-as-written line. Variable metadata
is JSON on the wrapper so the controller does not fetch.
EOF
)"
```

---

### Task 4: Injected row uses the same markup

**Files:**
- Modify: `test/controllers/steps_panel_edit_stimulus_values_test.rb` (or a tiny `test/javascript`-style file that reads the controller as text — this repo has no JS runner; read the file in a Minitest case)
- Modify: `app/javascript/controllers/step_transitions_controller.js`

- [ ] **Step 1: Failing test that the JS template contains the sentence targets and not customInput**

Add to `steps_panel_edit_stimulus_values_test.rb`:

```ruby
test "the JS-injected connection row uses the same sentence markup as the ERB" do
  source = Rails.root.join("app/javascript/controllers/step_transitions_controller.js").read
  %w[sentenceContainer sentenceVariable sentenceOperator sentenceValue keepAsWritten].each do |target|
    assert_includes source, %(data-condition-preset-target="#{target}"),
                    "step_transitions_controller.js is missing #{target} — Add Connection would ship the old Custom field"
  end
  assert_not_includes source, "customInput"
  assert_not_includes source, "e.g., answer =="
end
```

- [ ] **Step 2: Run it — expect fail**

```
bin/rails test test/controllers/steps_panel_edit_stimulus_values_test.rb -n "/JS-injected/"
```

- [ ] **Step 3: Add `variables` to `step_transitions` values and replace the custom block in `renderTransitions`**

```javascript
static values = {
  stepId: String,
  stepIndex: Number,
  variables: Array
}
```

In the template string, replace the `customContainer` div with the same sentence markup as the ERB (same target names, same `handleSentenceChange` action). On the `condition-preset` wrapper add:

```
data-condition-preset-variables-value="${this.escapeHtml(JSON.stringify(this.variablesValue || []))}"
```

- [ ] **Step 4: Run the JS-template test — expect pass**

```
bin/rails test test/controllers/steps_panel_edit_stimulus_values_test.rb
```

- [ ] **Step 5: Commit**

```
git add app/javascript/controllers/step_transitions_controller.js test/controllers/steps_panel_edit_stimulus_values_test.rb
git commit -m "$(cat <<'EOF'
Give Add Connection the same condition sentence as the ERB row

The two templates must not drift: a JS-injected row is how every
connection after the first is born.
EOF
)"
```

---

### Task 5: Sentence CSS

**Files:**
- Modify: `app/assets/stylesheets/workflows.css` (after `.transition-item__condition`)

- [ ] **Step 1: Add compact sentence rules** (no new colour tokens)

```css
.condition-sentence {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-1);
  min-width: 0;
}

.condition-sentence__variable {
  flex: 1 1 8rem;
  min-width: 0;
}

.condition-sentence__operator {
  flex: 0 0 auto;
}

.condition-sentence__value {
  flex: 1 1 6rem;
  min-width: 0;
}

.condition-sentence__value .form-select,
.condition-sentence__value .form-input {
  width: 100%;
}

.condition-sentence__kept {
  flex: 1 0 100%;
  margin: 0;
  font-size: var(--text-xs);
  color: var(--color-ink-muted);
}
```

- [ ] **Step 2: Commit** (no test — visual; verify in Task 10’s browser walk)

```
git add app/assets/stylesheets/workflows.css
git commit -m "$(cat <<'EOF'
Size the condition sentence to sit in the connection row
EOF
)"
```

---

### Task 6: Controller owns the sentence (failing system tests first)

**Files:**
- Modify: `test/system/workflow_builder_test.rb`
- Modify: `app/javascript/controllers/condition_preset_controller.js`

Existing tests that look for `customContainer` must use `sentenceContainer` once markup is gone, or they error. Update those two `is-hidden` assertions in the Yes/No and option restore tests to `sentenceContainer` **in this task** so the preset tests stay green while Custom tests go red for the right reason.

- [ ] **Step 1: Update existing preset tests’ hidden-container selector to `sentenceContainer`**

Replace:

```ruby
assert_selector "[data-condition-preset-target='customContainer'].is-hidden", visible: :all
```

with:

```ruby
assert_selector "[data-condition-preset-target='sentenceContainer'].is-hidden", visible: :all
```

in both Yes/No and option restore tests.

- [ ] **Step 2: Write failing system tests (spec 2, 3, 4, 5, 6)**

Helpers on the class (next to `preset_dropdown`):

```ruby
def sentence_variable
  find("select[data-condition-preset-target='sentenceVariable']")
end

def sentence_operator
  find("select[data-condition-preset-target='sentenceOperator']")
end

def condition_hidden
  find("[data-condition-preset-target='conditionHidden']", visible: :all)
end
```

```ruby
test "choosing Custom shows the sentence, not a raw condition field" do
  question = Steps::Question.create!(
    workflow: @workflow, title: "Did it work?", position: 1,
    question: "Did it work?", answer_type: "yes_no", variable_name: "verified"
  )
  Transition.create!(step: question, target_step: @resolve, position: 0)

  visit_builder_in_edit_mode
  step_row(question.uuid).click

  within "turbo-frame#builder-panel" do
    assert_selector "select[data-condition-preset-target='presetDropdown']", wait: 5
    select "Custom...", from: find("select[data-condition-preset-target='presetDropdown']")[:id] rescue
      find("select[data-condition-preset-target='presetDropdown']").find("option[value='__custom__']").select_option

    assert_selector "[data-condition-preset-target='sentenceContainer']:not(.is-hidden)", wait: 5
    assert_selector "select[data-condition-preset-target='sentenceVariable']"
    assert_no_selector "[data-condition-preset-target='customInput']"
    assert_no_text "e.g., answer =="
  end
end
```

Capybara: the preset `<select>` has no `id`/`name`. Select by finding the option:

```ruby
find("select[data-condition-preset-target='presetDropdown'] option[value='__custom__']").select_option
```

```ruby
test "Custom can point at another question's Yes" do
  earlier = Steps::Question.create!(
    workflow: @workflow, title: "Already verified?", position: 1,
    question: "Already?", answer_type: "yes_no", variable_name: "already_verified"
  )
  later = Steps::Question.create!(
    workflow: @workflow, title: "Did it work?", position: 2,
    question: "Work?", answer_type: "yes_no", variable_name: "verified"
  )
  Transition.create!(step: later, target_step: @resolve, position: 0)

  visit_builder_in_edit_mode
  step_row(later.uuid).click

  within "turbo-frame#builder-panel" do
    find("select[data-condition-preset-target='presetDropdown'] option[value='__custom__']").select_option
    assert_selector "select[data-condition-preset-target='sentenceVariable']", wait: 5
    sentence_variable.select("Already verified?")
    sentence_operator.select("is")
    find("[data-condition-preset-target='sentenceValue'] select, [data-condition-preset-target='sentenceValue']").find("option[value='yes']").select_option

    assert_eventually do
      condition_hidden.value == "already_verified == 'yes'"
    end
  end
end

test "a condition on another question restores as a filled sentence" do
  earlier = Steps::Question.create!(
    workflow: @workflow, title: "Already verified?", position: 1,
    question: "Already?", answer_type: "yes_no", variable_name: "already_verified"
  )
  later = Steps::Question.create!(
    workflow: @workflow, title: "Did it work?", position: 2,
    question: "Work?", answer_type: "yes_no", variable_name: "verified"
  )
  Transition.create!(
    step: later, target_step: @resolve, position: 0,
    condition: "already_verified == 'yes'"
  )

  visit_builder_in_edit_mode
  step_row(later.uuid).click

  within "turbo-frame#builder-panel" do
    assert_eventually { preset_dropdown.value == "__custom__" }
    assert_selector "[data-condition-preset-target='sentenceContainer']:not(.is-hidden)"
    assert_equal "already_verified", sentence_variable.value
    assert_no_selector "[data-condition-preset-target='customInput']"
  end
end

test "an unparseable condition is kept as written" do
  question = Steps::Question.create!(
    workflow: @workflow, title: "Did it work?", position: 1,
    question: "Did it work?", answer_type: "yes_no", variable_name: "verified"
  )
  Transition.create!(
    step: question, target_step: @resolve, position: 0,
    condition: "not a real condition"
  )

  visit_builder_in_edit_mode
  step_row(question.uuid).click

  within "turbo-frame#builder-panel" do
    assert_eventually { preset_dropdown.value == "__custom__" }
    kept = find("[data-condition-preset-target='keepAsWritten']")
    assert_includes kept.text, "not a real condition"
    assert_equal "not a real condition", condition_hidden.value
  end
end
```

Tighten the existing `"an unmatched condition stays Custom"` test (`verified == 'maybe'`): still `__custom__`, **and** Keep as written contains `verified == 'maybe'`, hidden field unchanged. That is the representability rule.

```ruby
test "Add Connection's Custom path is the sentence" do
  question = Steps::Question.create!(
    workflow: @workflow, title: "Did it work?", position: 1,
    question: "Did it work?", answer_type: "yes_no", variable_name: "verified"
  )

  visit_builder_in_edit_mode
  step_row(question.uuid).click

  within "turbo-frame#builder-panel" do
    click_on "Add Connection"
    assert_selector "[data-condition-preset-target='sentenceContainer']", visible: :all, wait: 5
    within all(".transition-item").last do
      find("select[data-condition-preset-target='presetDropdown'] option[value='__custom__']").select_option
      assert_selector "[data-condition-preset-target='sentenceVariable']"
      assert_no_selector "[data-condition-preset-target='customInput']"
    end
  end
end
```

- [ ] **Step 3: Run the new system tests — expect fail** (sentence not wired)

```
bin/rails test test/system/workflow_builder_test.rb:112
```

(or `-n "/Custom shows the sentence|another question|filled sentence|kept as written|Add Connection's Custom/"`)

Preset restore tests must still pass after the selector rename:

```
bin/rails test test/system/workflow_builder_test.rb -n "/Yes preset|that option/"
```

- [ ] **Step 4: Implement sentence logic in `condition_preset_controller.js`**

Targets — remove `customInput` / `customContainer`; add:

```javascript
static targets = [
  "presetDropdown",
  "sentenceContainer",
  "sentenceVariable",
  "sentenceOperator",
  "sentenceValue",
  "keepAsWritten",
  "labelInput",
  "numericValueInput",
  "numericContainer",
  "conditionHidden"
]

static values = {
  condition: String,
  label: String,
  variables: Array
}
```

Rename `showCustomInput` / `hideCustomInput` to operate on `sentenceContainer` (`is-hidden` plus `hidden` on keep-as-written).

**Populate** (call from `connect` after `buildPresets`, and when opening Custom):

- Fill `sentenceVariable` from `this.variablesValue` (`option.value = var.name`, `textContent = var.title` — title only, not `display_name` with the raw name).
- Default selected variable: this step’s `stepInfo.variableName` if present in the list, else the first option.

**Operators / value** on variable change (`handleSentenceChange` and initial populate):

- `answer_type === 'number'`: operators equals `==`, does not equal `!=`, greater than `>`, at least `>=`, less than `<`, at most `<=`. Value = `<input type="number">` inside `sentenceValue`.
- Else: *is* `==`, *is not* `!=`. Value:
  - yes_no → select Yes/`yes`, No/`no`
  - multiple_choice / dropdown with options → select of `opt.label` / `opt.value`
  - else → text input

**Write** (`writeSentenceCondition`): if variable is blank or value is `''`, return without calling `updateCondition` (incomplete sentence). Else:

- numeric ops `>`, `>=`, `<`, `<=`, or `==`/`!=` when `answer_type === 'number'`: `` `${variable} ${op} ${value}` `` (unquoted digits, matching this-step numeric presets)
- else: `` `${variable} ${op} '${value.replace(/'/g, "\\'")}'` ``

Any write clears keep-as-written (`hidden` + `is-hidden`, empty text).

**Opening Custom** (`handlePresetChange` `__custom__`): show sentence, hide numeric, **do not** `updateCondition('')`. Populate the sentence defaults. Incomplete → hidden field stays as it was.

**Restore** — after preset match and this-step numeric match, instead of stuffing `customInput`:

```javascript
const parsed = this.parseCondition(condition)
if (parsed && this.fillSentence(parsed)) {
  this.selectPreset('__custom__')
  this.showSentence()
  this.hideNumericInput()
  this.hideKeepAsWritten()
  return
}

this.selectPreset('__custom__')
this.showSentence()
this.hideNumericInput()
this.showKeepAsWritten(condition)
```

`parseCondition` (same shapes as the deleted `visual_condition_controller.js`, whose last version the design doc shows how to read):

```javascript
parseCondition(condition) {
  const stringMatch = condition.trim().match(/^(\w+)\s*(==|!=)\s*['"]([^'"]*)['"]\s*$/)
  if (stringMatch) return { variable: stringMatch[1], operator: stringMatch[2], value: stringMatch[3] }
  const numericMatch = condition.trim().match(/^(\w+)\s*(==|!=|>|>=|<|<=)\s*(\d+)\s*$/)
  if (numericMatch) return { variable: numericMatch[1], operator: numericMatch[2], value: numericMatch[3] }
  return null
}
```

`fillSentence(parsed)` returns false (caller keeps as written) when:

- `parsed.variable` is not in `variablesValue`, or
- after applying operators/value control for that variable, the value cannot be represented (yes_no select has no `'maybe'`; option select has no that value).

When true: set variable, rebuild operator/value, set operator and value. Do not call `updateCondition` (hidden field already has the stored string).

`showKeepAsWritten(text)`: set text to `Keep as written: ${text}`, remove `hidden` / `is-hidden`.

- [ ] **Step 5: Run system tests — expect pass**

```
bin/rails test test/system/workflow_builder_test.rb
```

Expected: all tests in the file green, including the six spec behaviours and the existing Yes/No / option restores.

- [ ] **Step 6: Gate**

```
bin/rails test test/system/workflow_builder_test.rb \
  test/controllers/steps_panel_edit_stimulus_values_test.rb \
  test/helpers/workflows_helper_test.rb \
  test/integration/runner_shell_parity_test.rb
```

Expected: green. `runner_shell_parity_test.rb` is unchanged behaviour.

- [ ] **Step 7: Browser walk** (Cancellation Triage, edit)

1. Step 1 “Already verified this contact?” — first connection still **Yes**, not Custom.
2. Choose Custom on a blank connection — sentence appears; no `e.g., answer ==`.
3. Step that is not a Yes/No: Custom, pick “Already verified this contact?”, is, Yes — hidden/autosave is `already_verified == 'yes'`.
4. Narrow the panel (desktop and ~1024) — sentence wraps inside the card, does not blow the page.

- [ ] **Step 8: Commit**

```
git add app/javascript/controllers/condition_preset_controller.js test/system/workflow_builder_test.rb
git commit -m "$(cat <<'EOF'
Build Custom conditions as a sentence instead of a raw expression

Presets stay one click. Custom picks a question by title, is/is not
(or a numeric compare), and a value, and writes the engine dialect.
Unparseable strings stay Keep as written until the author edits.
EOF
)"
```

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Custom only; presets stay | Task 6 (existing Yes/No tests stay green) |
| Any question, this step first | Task 1 + sentence variable list |
| No raw field in happy path | Tasks 2–4, 6 |
| Sentence controls + dialect table | Task 6 `writeSentenceCondition` |
| Restore 1–2 (blank / this-step preset) | Already shipped; selector update in Task 6 |
| Restore 3 (other variable) | Task 6 filled-sentence test |
| Restore 4 + representability | Task 6 keep-as-written + `maybe` |
| Incomplete sentence does not write | Task 6 Custom open does not `updateCondition('')` |
| Add Connection same markup | Task 4 + system test |
| No `visual_condition_controller` wire | File map |
| No VariablesController change | File map |
| `runner_shell_parity` green | Task 6 gate |

## Out of scope (do not add tasks)

AND/OR, action output fields, diagram-as-editor, resurrecting `visual_condition_controller.js`, changing `ConditionEvaluator`.
