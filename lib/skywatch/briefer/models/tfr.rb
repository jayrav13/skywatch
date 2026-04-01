# frozen_string_literal: true

module Skywatch
  module Briefer
    module Models
      class Tfr
        attr_reader :notam_key, :title, :state, :type, :center_id,
                    :last_modified, :coords

        def self.from_geojson_feature(feature) # rubocop:disable Metrics/MethodLength
          props = feature['properties']
          geom = feature['geometry']

          new(
            notam_key: props['NOTAM_KEY'],
            title: props['TITLE'],
            state: props['STATE'],
            type: props['LEGAL'],
            center_id: props['CNS_LOCATION_ID'],
            last_modified: parse_datetime(props['LAST_MODIFICATION_DATETIME']),
            coords: parse_geojson_coords(geom)
          )
        end

        def initialize(**attrs)
          @notam_key = attrs[:notam_key]
          @title = attrs[:title]
          @state = attrs[:state]
          @type = attrs[:type]
          @center_id = attrs[:center_id]
          @last_modified = attrs[:last_modified]
          @coords = attrs[:coords]
        end

        def polygon
          Skywatch::Shared::Geometry.polygon_from_coords(coords)
        end

        def to_h
          {
            notam_key: notam_key, title: title, state: state, type: type,
            center_id: center_id, last_modified: last_modified&.iso8601,
            coords: coords&.map { |c| { lat: c.lat, lon: c.lon } }
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        def self.parse_datetime(str)
          return nil if str.nil? || str.empty?

          Time.utc(str[0, 4].to_i, str[4, 2].to_i, str[6, 2].to_i, str[8, 2].to_i, str[10, 2].to_i)
        end

        def self.parse_geojson_coords(geom)
          return [] if geom.nil? || geom['coordinates'].nil?

          # GeoJSON is [lon, lat], Position is (lat, lon)
          geom['coordinates'][0].map { |lon, lat| Skywatch::Shared::Position.new(lat: lat, lon: lon) }
        end

        private_class_method :parse_datetime, :parse_geojson_coords
      end
    end
  end
end
