module Nepse
  # Records which source supplied each field, in the record's field_sources column:
  #   { "eps" => { "source" => "chukul", "at" => "2026-09-28T10:45:00Z" } }
  module Provenance
    SOURCES = %w[chukul merolagani sharesansar computed].freeze

    module_function

    # Assigns values that are present and records their source. Blank values are
    # skipped so a later (lower-priority) source can still fill them.
    def assign(record, values, source)
      raise ArgumentError, "unknown source #{source}" unless SOURCES.include?(source)

      stamp = Time.current.iso8601
      filled = values.reject { |_field, value| blank?(value) }
      record.assign_attributes(filled)
      record.field_sources = record.field_sources.merge(filled.keys.to_h { [ _1.to_s, { "source" => source, "at" => stamp } ] })
      filled.keys
    end

    # A field is missing if it is blank or still at its zero default.
    def blank?(value)
      value.nil? || value == "" || (value.is_a?(Numeric) && value.zero?)
    end
  end
end
