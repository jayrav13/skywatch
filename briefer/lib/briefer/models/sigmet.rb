# frozen_string_literal: true

module Briefer
  module Models
    class Sigmet
      attr_reader :series_id, :issuing_center, :sigmet_type, :hazard, :severity,
                  :raw, :valid_from, :valid_to,
                  :altitude_hi_ft, :altitude_low_ft,
                  :movement_dir_deg, :movement_speed_kt, :coords

      def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        new(
          series_id: data["seriesId"],
          issuing_center: data["icaoId"],
          sigmet_type: data["airSigmetType"]&.downcase&.to_sym || :sigmet,
          hazard: data["hazard"],
          severity: data["severity"],
          raw: data["rawAirSigmet"],
          valid_from: Time.at(data["validTimeFrom"]).utc,
          valid_to: Time.at(data["validTimeTo"]).utc,
          altitude_hi_ft: data["altitudeHi1"],
          altitude_low_ft: data["altitudeLow1"],
          movement_dir_deg: data["movementDir"],
          movement_speed_kt: data["movementSpd"],
          coords: parse_coords(data["coords"])
        )
      end

      def initialize(**attrs) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        @series_id = attrs[:series_id]
        @issuing_center = attrs[:issuing_center]
        @sigmet_type = attrs[:sigmet_type]
        @hazard = attrs[:hazard]
        @severity = attrs[:severity]
        @raw = attrs[:raw]
        @valid_from = attrs[:valid_from]
        @valid_to = attrs[:valid_to]
        @altitude_hi_ft = attrs[:altitude_hi_ft]
        @altitude_low_ft = attrs[:altitude_low_ft]
        @movement_dir_deg = attrs[:movement_dir_deg]
        @movement_speed_kt = attrs[:movement_speed_kt]
        @coords = attrs[:coords]
      end

      def polygon
        Geometry.polygon_from_coords(coords)
      end

      def to_h # rubocop:disable Metrics/AbcSize
        {
          series_id: series_id, issuing_center: issuing_center,
          sigmet_type: sigmet_type, hazard: hazard, severity: severity,
          raw: raw,
          valid_from: valid_from&.iso8601, valid_to: valid_to&.iso8601,
          altitude_hi_ft: altitude_hi_ft, altitude_low_ft: altitude_low_ft,
          movement_dir_deg: movement_dir_deg, movement_speed_kt: movement_speed_kt,
          coords: coords&.map { |c| { lat: c.lat, lon: c.lon } }
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end

      def self.parse_coords(coords_data)
        return [] if coords_data.nil?

        coords_data.map { |c| Position.new(lat: c["lat"].to_f, lon: c["lon"].to_f) }
      end

      private_class_method :parse_coords
    end
  end
end
