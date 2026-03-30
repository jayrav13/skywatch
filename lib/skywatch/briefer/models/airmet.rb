# frozen_string_literal: true

require "time"

module Skywatch
  module Briefer
    module Models
      class Airmet
        attr_reader :tag, :product, :hazard, :due_to, :severity,
                    :forecast_hour, :valid_at, :issued_at, :expires_at,
                    :top, :base, :freeze_level_top, :freeze_level_base, :coords

        def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          new(
            tag: data["tag"],
            product: data["product"]&.downcase&.to_sym,
            hazard: data["hazard"],
            due_to: blank_to_nil(data["due_to"]),
            severity: blank_to_nil(data["severity"]),
            forecast_hour: data["forecastHour"],
            valid_at: Time.parse(data["validTime"]).utc,
            issued_at: Time.at(data["issueTime"]).utc,
            expires_at: Time.at(data["expireTime"]).utc,
            top: blank_to_nil(data["top"]),
            base: blank_to_nil(data["base"]),
            freeze_level_top: blank_to_nil(data["fzltop"]),
            freeze_level_base: blank_to_nil(data["fzlbase"]),
            coords: parse_coords(data["coords"])
          )
        end

        def initialize(**attrs) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          @tag = attrs[:tag]
          @product = attrs[:product]
          @hazard = attrs[:hazard]
          @due_to = attrs[:due_to]
          @severity = attrs[:severity]
          @forecast_hour = attrs[:forecast_hour]
          @valid_at = attrs[:valid_at]
          @issued_at = attrs[:issued_at]
          @expires_at = attrs[:expires_at]
          @top = attrs[:top]
          @base = attrs[:base]
          @freeze_level_top = attrs[:freeze_level_top]
          @freeze_level_base = attrs[:freeze_level_base]
          @coords = attrs[:coords]
        end

        def polygon
          Skywatch::Shared::Geometry.polygon_from_coords(coords)
        end

        def to_h # rubocop:disable Metrics/AbcSize
          {
            tag: tag, product: product, hazard: hazard, due_to: due_to,
            severity: severity, forecast_hour: forecast_hour,
            valid_at: valid_at&.iso8601, issued_at: issued_at&.iso8601,
            expires_at: expires_at&.iso8601,
            top: top, base: base,
            freeze_level_top: freeze_level_top, freeze_level_base: freeze_level_base,
            coords: coords&.map { |c| { lat: c.lat, lon: c.lon } }
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        def self.blank_to_nil(value)
          return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

          value
        end

        def self.parse_coords(coords_data)
          return [] if coords_data.nil?

          coords_data.map { |c| Skywatch::Shared::Position.new(lat: c["lat"].to_f, lon: c["lon"].to_f) }
        end

        private_class_method :blank_to_nil, :parse_coords
      end
    end
  end
end
