# frozen_string_literal: true

require 'rgeo'
require 'rgeo/geo_json'
require 'time'

module Skywatch
  module Nimbus
    module Models
      class Outlook
        FACTORY = RGeo::Cartesian.factory(srid: 4326)

        RISK_LEVELS = {
          'TSTM' => { level: :general_thunder, score: 1, description: 'General Thunderstorms' },
          'MRGL' => { level: :marginal,        score: 2, description: 'Marginal Risk' },
          'SLGT' => { level: :slight,          score: 3, description: 'Slight Risk' },
          'ENH' => { level: :enhanced,        score: 4, description: 'Enhanced Risk' },
          'MDT' => { level: :moderate,        score: 5, description: 'Moderate Risk' },
          'HIGH' => { level: :high, score: 6, description: 'High Risk' }
        }.freeze

        attr_reader :day, :label, :valid_from, :valid_to, :issued_at, :forecaster, :geometry

        def self.from_spc_feature(feature, day:) # rubocop:disable Metrics/MethodLength
          geometry_data = feature['geometry']
          raise Skywatch::ParseError, 'SPC outlook feature missing geometry' if geometry_data.nil?

          props = feature['properties'] || {}
          new(
            day: day,
            label: props['LABEL'],
            valid_from: parse_time(props['VALID_ISO']),
            valid_to: parse_time(props['EXPIRE_ISO']),
            issued_at: parse_time(props['ISSUE_ISO']),
            forecaster: props['FORECASTER'],
            geometry: RGeo::GeoJSON.decode(geometry_data, geo_factory: FACTORY)
          )
        end

        def self.parse_time(value)
          return nil if value.nil? || value.empty?

          Time.parse(value).utc
        end
        private_class_method :parse_time

        def initialize(day:, label:, valid_from:, valid_to:, issued_at:, forecaster:, geometry:) # rubocop:disable Metrics/ParameterLists
          @day = day
          @label = label
          @valid_from = valid_from
          @valid_to = valid_to
          @issued_at = issued_at
          @forecaster = forecaster
          @geometry = geometry
        end

        def risk_level
          RISK_LEVELS.fetch(label)[:level]
        end

        def risk_score
          RISK_LEVELS.fetch(label)[:score]
        end

        def description
          RISK_LEVELS.fetch(label)[:description]
        end

        def covers?(lat:, lon:)
          return false if geometry.nil?

          geometry.contains?(FACTORY.point(lon, lat))
        rescue RGeo::Error::InvalidGeometry
          false
        end

        def to_h # rubocop:disable Metrics/MethodLength
          {
            day: day,
            label: label,
            risk_level: risk_level,
            risk_score: risk_score,
            description: description,
            valid_from: valid_from&.iso8601,
            valid_to: valid_to&.iso8601,
            issued_at: issued_at&.iso8601,
            forecaster: forecaster,
            geometry: geometry && RGeo::GeoJSON.encode(geometry)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
