# frozen_string_literal: true

require 'time'
require 'rgeo/geo_json'

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

        KIND_BY_EVENT_SUFFIX = { 'Warning' => :warning, 'Watch' => :watch }.freeze

        SEVERITY_VALUES  = %w[Extreme Severe Moderate Minor Unknown].freeze
        CERTAINTY_VALUES = %w[Observed Likely Possible Unlikely Unknown].freeze
        URGENCY_VALUES   = %w[Immediate Expected Future Past Unknown].freeze

        FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

        def self.from_nws_feature(feature) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          props = feature.fetch('properties')
          event = props['event'].to_s

          new(
            id: props['id'] || feature['id'],
            kind: kind_for(event),
            event: event,
            headline: props['headline'].to_s,
            description: props['description'].to_s,
            severity: enum_or_unknown(props['severity'], SEVERITY_VALUES),
            certainty: enum_or_unknown(props['certainty'], CERTAINTY_VALUES),
            urgency: enum_or_unknown(props['urgency'], URGENCY_VALUES),
            sent_at: parse_time(props['sent']),
            effective_at: parse_time(props['effective']),
            onset_at: parse_time(props['onset']),
            expires_at: parse_time(props['expires']),
            ends_at: parse_time(props['ends']),
            area_description: props['areaDesc'].to_s,
            geometry: parse_geometry(feature['geometry']),
            hail_size_in: nil,
            wind_gust_mph: nil,
            wind_gust_kt: nil,
            tornado_detection: nil,
            thunderstorm_damage_threat: nil,
            flash_flood_damage_threat: nil,
            raw_parameters: props['parameters'] || {}
          )
        end

        def self.kind_for(event)
          suffix = event.split.last
          KIND_BY_EVENT_SUFFIX[suffix] || :unknown
        end
        private_class_method :kind_for

        def self.enum_or_unknown(value, allowed)
          return :unknown if value.nil?
          return :unknown unless allowed.include?(value)

          value.downcase.to_sym
        end
        private_class_method :enum_or_unknown

        def self.parse_time(str)
          return nil if str.nil? || str.empty?

          Time.parse(str).utc
        end
        private_class_method :parse_time

        def self.parse_geometry(geo_data)
          return nil if geo_data.nil?

          RGeo::GeoJSON.decode(geo_data, geo_factory: FACTORY, json_parser: :json)
        rescue StandardError
          nil
        end
        private_class_method :parse_geometry

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
