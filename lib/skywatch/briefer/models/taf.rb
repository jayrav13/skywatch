# frozen_string_literal: true

module Skywatch
  module Briefer
    module Models
      class Taf
        attr_reader :station_id, :raw, :issued_at, :valid_from, :valid_to,
                    :station_name, :latitude, :longitude, :elevation_ft,
                    :forecast_groups

        def self.from_awc(data) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          new(
            station_id: data['icaoId'],
            raw: data['rawTAF'],
            issued_at: Time.parse(data['issueTime']).utc,
            valid_from: Time.at(data['validTimeFrom']).utc,
            valid_to: Time.at(data['validTimeTo']).utc,
            station_name: data['name'],
            latitude: data['lat'],
            longitude: data['lon'],
            elevation_ft: data['elev'] ? (data['elev'] * 3.28084).round : nil,
            forecast_groups: data['fcsts']&.map { |f| TafGroup.from_awc(f) } || []
          )
        end

        def initialize(**attrs)
          @station_id = attrs[:station_id]
          @raw = attrs[:raw]
          @issued_at = attrs[:issued_at]
          @valid_from = attrs[:valid_from]
          @valid_to = attrs[:valid_to]
          @station_name = attrs[:station_name]
          @latitude = attrs[:latitude]
          @longitude = attrs[:longitude]
          @elevation_ft = attrs[:elevation_ft]
          @forecast_groups = attrs[:forecast_groups]
        end

        def position
          Skywatch::Shared::Position.new(lat: latitude, lon: longitude)
        end

        def group_at(time)
          forecast_groups.reverse.find { |g| time >= g.time_from && time < g.time_to }
        end

        def to_h
          {
            station_id: station_id, raw: raw, issued_at: issued_at&.iso8601,
            valid_from: valid_from&.iso8601, valid_to: valid_to&.iso8601,
            station_name: station_name, latitude: latitude, longitude: longitude,
            elevation_ft: elevation_ft,
            forecast_groups: forecast_groups.map(&:to_h)
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
