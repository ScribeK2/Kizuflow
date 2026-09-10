module Steps
  class Form < Step
    # The field types the form builder offers and the import schema publishes.
    VALID_FIELD_TYPES = %w[text textarea number email phone select checkbox].freeze

    has_rich_text :instructions

    # Fields are stored in the `options` JSON column as an array of hashes:
    #   [{ "name" => "phone", "label" => "Phone", "field_type" => "text", "required" => true, "position" => 0 }]
    #
    # A field of type "select" also carries its choices:
    #   "select_options" => [{ "label" => "IVR", "value" => "ivr" }]

    before_validation :drop_untouched_fields
    before_validation :normalize_select_options

    def step_type
      "form"
    end

    # Fields an author started but hasn't both named and labelled. The import
    # schema requires both, so an export carrying one is refused;
    # WorkflowHealthCheck lists each one on the step.
    def incomplete_fields
      fields.select { |field| field.is_a?(Hash) && (field["name"].blank? || field["label"].blank?) }
    end

    # The choices a select field offers, as stored. Empty for every other type.
    def select_options_for(field)
      Array(field.is_a?(Hash) ? field["select_options"] : nil)
    end

    # Those choices as the builder's one-line text, so an edit round-trips.
    def select_options_text(field)
      select_options_for(field).pluck("label").join(", ")
    end

    # Every select field with no choices the runner could render.
    #
    # Read by WorkflowHealthCheck, which surfaces each one as a warning on the
    # step. That matters beyond the runner: an export carries schema_version, so
    # it comes back down the strict path where StrictImportValidator refuses a
    # choiceless select outright — the health panel is where an operator finds
    # which workflows to fix before exporting one.
    #
    # "No choices" means the same thing here as in the validator: an entry that
    # is not a {label, value} pair cannot be rendered either. `["IVR"]` looks
    # populated and is not — `scenarios/_form_step` reads `opt["value"]` off it,
    # which is String#[] answering nil.
    def select_fields_without_choices
      fields.select do |field|
        next false unless field.is_a?(Hash) && field["field_type"] == "select"

        choices = select_options_for(field)
        choices.empty? || choices.any? do |choice|
          !choice.is_a?(Hash) || choice["label"].blank? || choice["value"].blank?
        end
      end
    end

    # Returns the field definitions (alias for options)
    def fields
      options || []
    end

    # Returns the names of all required fields
    def required_field_names
      fields.select { |f| f["required"] }.pluck("name")
    end

    # Look up a single field definition by name
    def field_by_name(name)
      fields.find { |f| f["name"] == name }
    end

    # Validate a hash of responses against the field definitions.
    #
    # Keyed by field name, so a refusal can be shown under the input it is
    # about. It used to return a flat array of sentences, which left a long form
    # rendering one block above the fields and the agent matching each message
    # back to an input by reading the label out of it. Escalate and Resolve have
    # exactly one field each and so never had the problem.
    #
    # Empty hash = valid.
    def validate_responses(response_data)
      fields.select { |f| f["required"] }.each_with_object({}) do |field, errors|
        next if response_data&.dig(field["name"]).present?

        errors[field["name"]] = ["#{field['label'] || field['name']} is required"]
      end
    end

    def outcome_summary
      count = fields.size
      required = required_field_names.size
      "#{count} field#{'s' if count != 1} (#{required} required)"
    end

    private

    # "+ Add Field" appends an empty row and autosaves straight away, so an
    # untouched row arrives with no name and no label. Nothing can answer it and
    # export would refuse it, so it isn't kept. A row with either filled is an
    # edit in progress and stays, listed by `incomplete_fields`.
    def drop_untouched_fields
      return unless options.is_a?(Array)

      self.options = options.reject do |field|
        field.is_a?(Hash) && field["name"].blank? && field["label"].blank?
      end
    end

    # The builder authors choices as one comma- or newline-separated string,
    # because `options` posts as an unindexed array — `step[options][][name]` —
    # and Rails groups those by watching for a repeated key. A nested array
    # inside one of those elements breaks that grouping, so the builder sends a
    # scalar and this turns it into the stored pairs.
    #
    # Import sends `select_options` already structured and no raw key at all,
    # which is why a nil raw leaves the stored choices alone rather than
    # clearing them. A *blank* raw is a deliberate "remove the choices".
    def normalize_select_options
      return if options.blank?

      self.options = Array(options).map do |field|
        next field unless field.is_a?(Hash)

        raw = field["select_options_raw"]
        field = field.except("select_options_raw")
        next field if raw.nil?

        # An unchanged raw box means "I did not touch the choices", not "rewrite
        # them from their labels". The builder renders the box on every field
        # row on every autosave, and its value is `select_options_text` — labels
        # only — so without this check a save triggered by an unrelated edit
        # flattened every choice's value to its label. That is invisible and
        # permanent: a transition matching `contact == 'phone'` silently stops
        # firing once the stored value becomes "Phone". A label containing the
        # separator was worse — "Yes, immediately" came back as two choices.
        #
        # Only import can author a choice whose value differs from its label, so
        # this is the round-trip that kept a bundle's forms intact.
        stored = stored_select_options_for(field)
        next field.merge("select_options" => stored) if stored.any? && raw == choices_text(stored)

        parsed = parse_select_options(raw)
        parsed.any? ? field.merge("select_options" => parsed) : field.except("select_options")
      end
    end

    # The choices this field had before the current assignment, matched by
    # `name` because that is the only stable identifier a field carries —
    # `position` is re-sent by the builder and can shift within one save.
    #
    # Renaming a field and leaving its choices alone in the same save misses
    # this lookup and falls through to the parse, which is the pre-existing
    # label=value behaviour rather than a new failure.
    def stored_select_options_for(field)
      name = field["name"]
      return [] if name.blank?

      previous = Array(options_in_database).find { |f| f.is_a?(Hash) && f["name"] == name }
      Array(previous && previous["select_options"])
    end

    def choices_text(choices)
      choices.filter_map { |choice| choice["label"] if choice.is_a?(Hash) }.join(", ")
    end

    def parse_select_options(raw)
      return Array(raw) if raw.is_a?(Array)

      raw.to_s.split(/[\n,]/).filter_map do |choice|
        label = choice.strip
        { "label" => label, "value" => label } if label.present?
      end
    end
  end
end
