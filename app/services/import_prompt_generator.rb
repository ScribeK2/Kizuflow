# The block a user copies into an external AI agent so it can write an import
# file. Generated from the same schema the agent validates against, so the two
# cannot drift — a prompt that describes a format the app no longer accepts is
# worse than no prompt.
#
# The worked example is a constant here rather than assembled, because it has to
# read like something a person would write. What keeps it honest is the test that
# runs it through StrictImportValidator: an example that does not import is worse
# than no example.
class ImportPromptGenerator
  EXAMPLE = <<~JSON.freeze
    {
      "schema_version": "1",
      "workflows": [
        {
          "title": "Internet Connection Troubleshooting",
          "description": "Basic connectivity checks for a customer whose internet is down.",
          "tags": ["support", "connectivity"],
          "steps": [
            {
              "id": "confirm-issue",
              "type": "question",
              "title": "Confirm the issue",
              "question": "Is the customer's internet completely down?",
              "answer_type": "yes_no",
              "variable_name": "fully_down",
              "transitions": [
                { "target_id": "restart-router", "condition": "fully_down == 'yes'" },
                { "target_id": "check-speed" }
              ]
            },
            {
              "id": "restart-router",
              "type": "action",
              "title": "Restart the router",
              "instructions": "<p>Ask the customer to unplug the router for <strong>30 seconds</strong>, then plug it back in and wait two minutes.</p>",
              "transitions": [{ "target_id": "did-it-work" }]
            },
            {
              "id": "did-it-work",
              "type": "question",
              "title": "Did that fix it?",
              "question": "Is the connection back?",
              "answer_type": "yes_no",
              "variable_name": "fixed",
              "transitions": [
                { "target_id": "resolved", "condition": "fixed == 'yes'" },
                { "target_id": "restart-router" }
              ]
            },
            {
              "id": "check-speed",
              "type": "message",
              "title": "Check the speed",
              "content": "<p>Run a speed test with the customer and note the result.</p>",
              "transitions": [{ "target_id": "resolved" }]
            },
            {
              "id": "resolved",
              "type": "resolve",
              "title": "Issue resolved",
              "resolution_type": "success"
            }
          ]
        }
      ]
    }
  JSON

  def self.call = new.call

  def initialize
    @schema = ImportSchemaGenerator.call
  end

  def call
    [preamble, step_type_section, rules_section, example_section].join("\n")
  end

  private

  def preamble
    <<~MD
      # Writing a TurboFlows workflow file

      Produce a single JSON file in exactly this envelope:

      ```
      { "schema_version": "#{ImportSchemaGenerator::SCHEMA_VERSION}", "workflows": [ { ...a workflow... } ] }
      ```

      One file may carry a set of up to #{ImportSchemaGenerator::MAX_WORKFLOWS_PER_FILE} workflows, imported
      together. Split a domain into several when the parts are separately
      reusable — a diagnosis that routes into four procedures belongs as five
      workflows, not as one of seventy steps. The full JSON Schema is at
      `#{ImportSchemaGenerator::SCHEMA_URL}` — validate against it before handing the
      file over.

      A workflow needs a `title` and a `steps` array. It may also carry
      `description`, `tags` (plain names), `groups` (see below), `folder`, and
      `start_step_id` (defaults to the first step).
    MD
  end

  def step_type_section
    rows = Workflow::VALID_STEP_TYPES.map do |type|
      required = branch(type)["required"] - %w[id type title transitions]
      optional = branch(type)["properties"].keys - branch(type)["required"] -
                 %w[help_text reference_url]
      "| `#{type}` | #{fields(required)} | #{fields(optional)} |"
    end

    <<~MD
      ## Step types

      Every step needs `id`, `type`, `title`, and — except for `resolve` —
      at least one transition.

      | type | also required | optional |
      |---|---|---|
      #{rows.join("\n")}

      Every step also accepts `help_text` and `reference_url`.
    MD
  end

  def rules_section
    <<~MD
      ## Rules that are easy to get wrong

      **Ids.** Every step needs an `id` you choose: 1-64 characters of letters,
      digits, hyphen or underscore. Readable slugs like `verify-account` beat
      UUIDs — transitions reference them, so you can check your own work.

      **Transitions are explicit.** Every step except `resolve` needs at least
      one. Nothing is inferred. A `resolve` step must have none at all.
      `target_id` names another step's `id` in the same workflow. A transition
      never crosses from one workflow to another — that is what `sub_flow` is for.

      **Loops are allowed** — "didn't work, try again" is a normal shape. What is
      refused is a loop with no way out: from every step, some path must still be
      able to reach a `resolve` step.

      **Rich text is HTML, not Markdown.** `instructions`, `content`, `notes` and
      `description` are stored as HTML — use `<p>`, `<strong>`, `<em>`,
      `<ul>/<ol>/<li>`, `<a href>`. Markdown is not converted and will render
      literally, asterisks and all.

      **Conditions are one comparison.** No `&&` or `||`, string values quoted,
      numbers whole and positive. Supported forms:
      #{StrictImportValidator::CONDITION_FORMS.map { |f| "`#{f}`" }.join(', ')}.
      A condition outside these silently never fires, so the import refuses it.

      **Variables.** `variable_name` on a question stores the answer; refer to it
      in a condition, or interpolate it into text as `{{variable_name}}`.

      **Groups** are named by path from the root, e.g.
      `"groups": ["Support / Tier 2"]`. The group must already exist and you must
      have access to it. Use `["Support", "Tier 2"]` if a name contains a slash.

      **Form fields of type `select` must list their choices.** Put them in
      `select_options` on the field, as `{"label": ..., "value": ...}` — the same
      shape a question's `options` uses. A select with no `select_options`
      renders as an empty dropdown the agent cannot answer, so do not encode the
      choices in the label text.

      **Sub-flows** name their target by `target_workflow_title`. That title may
      be another workflow **in this same file** — which is the reason to put a
      linked set in one file, since it then needs nothing to exist beforehand.
      Otherwise it must match a workflow that already exists and is published.
      Two workflows in one file cannot share a title, because that is how a
      target is matched. To hand variables to one, use
      `variable_mapping`, written `{"name_here": "name_inside_the_sub_flow"}` —
      the key is this workflow's name for the value, the value is the sub-flow's.
      **Only mapped variables cross**, so a sub-flow that interpolates
      `{{something}}` it was not given renders blank. Map everything the
      sub-flow's text or conditions refer to.
    MD
  end

  def example_section
    <<~MD
      ## A complete example

      Note the retry loop: `did-it-work` sends the agent back to `restart-router`,
      and the flow is still valid because `resolved` stays reachable from every
      step.

      ```json
      #{EXAMPLE.strip}
      ```
    MD
  end

  def branch(type)
    @schema["$defs"]["step"]["oneOf"].find { |b| b["properties"]["type"]["const"] == type }
  end

  def fields(names)
    names.empty? ? "—" : names.map { |n| "`#{n}`" }.join(", ")
  end
end
