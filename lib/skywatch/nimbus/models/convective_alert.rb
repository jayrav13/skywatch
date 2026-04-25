# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class ConvectiveAlert
        ATTRS = %i[
          id kind event headline description
          severity certainty urgency
          sent_at effective_at onset_at expires_at ends_at
          area_description geometry
          hail_size_in wind_gust_mph wind_gust_kt
          tornado_detection thunderstorm_damage_threat flash_flood_damage_threat
          raw_parameters
        ].freeze

        attr_reader(*ATTRS)

        def initialize(**attrs)
          ATTRS.each { |a| instance_variable_set(:"@#{a}", attrs[a]) }
        end

        def warning?
          kind == :warning
        end

        def watch?
          kind == :watch
        end
      end
    end
  end
end
