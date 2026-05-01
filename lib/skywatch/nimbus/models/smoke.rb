# frozen_string_literal: true

require 'rgeo'
require 'rgeo/geo_json'
require 'date'
require 'time'

module Skywatch
  module Nimbus
    module Models
      class Smoke
        FACTORY = RGeo::Cartesian.factory(srid: 4326)

        DENSITY_LEVELS = {
          'Light' => { level: :light, score: 1, description: 'Light smoke' },
          'Medium' => { level: :medium, score: 2, description: 'Medium smoke' },
          'Heavy' => { level: :heavy, score: 3, description: 'Heavy smoke' }
        }.freeze

        attr_reader :density_raw, :satellite, :start_time, :end_time, :geometry

        def self.from_arcgis_feature(feature)
          attrs = feature['attributes'] || {}
          new(
            density_raw: attrs['Density'],
            satellite: attrs['Satellite'],
            start_time: parse_julian(attrs['Start']),
            end_time: parse_julian(attrs['End_']),
            geometry: parse_arcgis_polygon(feature['geometry'])
          )
        end

        # Parses "YYYYDDD HHMM" (e.g. "2026120 1200") to a UTC Time.
        def self.parse_julian(str) # rubocop:disable Metrics/AbcSize
          return nil if str.nil? || str.to_s.empty?

          date_part, time_part = str.split(' ', 2)
          year = date_part[0, 4].to_i
          doy  = date_part[4..].to_i
          hh   = time_part ? time_part[0, 2].to_i : 0
          mm   = time_part && time_part.length >= 4 ? time_part[2, 2].to_i : 0
          d = Date.ordinal(year, doy)
          Time.utc(d.year, d.month, d.day, hh, mm)
        end
        private_class_method :parse_julian

        def self.parse_arcgis_polygon(geometry_data)
          return nil if geometry_data.nil?

          rings = geometry_data['rings'] || []
          return nil if rings.empty?

          outer = rings.first
          points = outer.map { |(lon, lat)| FACTORY.point(lon, lat) }
          ring = FACTORY.linear_ring(points)
          FACTORY.polygon(ring)
        end
        private_class_method :parse_arcgis_polygon

        def initialize(density_raw:, satellite:, start_time:, end_time:, geometry:)
          @density_raw = density_raw
          @satellite   = satellite
          @start_time  = start_time
          @end_time    = end_time
          @geometry    = geometry
        end

        def density_level
          DENSITY_LEVELS.fetch(density_raw)[:level]
        end

        def density_score
          DENSITY_LEVELS.fetch(density_raw)[:score]
        end

        def description
          DENSITY_LEVELS.fetch(density_raw)[:description]
        end

        def to_h
          {
            density: density_level_or_nil,
            density_raw: density_raw,
            density_score: density_score_or_nil,
            description: description_or_nil,
            satellite: satellite,
            start_time: start_time&.iso8601,
            end_time: end_time&.iso8601,
            geometry: geometry && RGeo::GeoJSON.encode(geometry)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        private

        def density_level_or_nil
          DENSITY_LEVELS.fetch(density_raw)[:level]
        rescue KeyError
          nil
        end

        def density_score_or_nil
          DENSITY_LEVELS.fetch(density_raw)[:score]
        rescue KeyError
          nil
        end

        def description_or_nil
          DENSITY_LEVELS.fetch(density_raw)[:description]
        rescue KeyError
          nil
        end
      end
    end
  end
end
