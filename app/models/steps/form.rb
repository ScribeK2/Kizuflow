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

    before_validation :normalize_select_options

    def step_type
      "form"
    end

    # The choices a select field offers, as stored. Empty for every other type.
    def select_options_for(field)
      Array(field.is_a?(Hash) ? field["select_options"] : nil)
    end

    # Those choices as the builder's one-line text, so an edit round-trips.
    def select_options_text(field)
      select_options_for(field).pluck("label").join(", ")
    end

    # Every select field that has no choices to offer. Such a field renders a
    # dropdown the agent cannot answer, which is why the strict dialect refuses
    # it and the builder marks it.
    def select_fields_without_choices
      fields.select do |field|
        field.is_a?(Hash) && field["field_type"] == "select" && select_options_for(field).empty?
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

        parsed = parse_select_options(raw)
        parsed.any? ? field.merge("select_options" => parsed) : field.except("select_options")
      end
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
