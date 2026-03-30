# frozen_string_literal: true

module Skywatch
  module Briefer
    module Models
      class Pirep
        attr_reader :raw, :observed_at, :pirep_type, :aircraft_type,
                    :latitude, :longitude, :flight_level,
                    :temperature_c, :wind_direction_deg, :wind_speed_kt,
                    :icing_intensity, :icing_type, :icing_base_ft, :icing_top_ft,
                    :turbulence_intensity, :turbulence_type, :turbulence_base_ft, :turbulence_top_ft

        def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
          new(
            raw: data["rawOb"],
            observed_at: Time.at(data["obsTime"]).utc,
            pirep_type: data["pirepType"]&.downcase&.to_sym || :pirep,
            aircraft_type: data["acType"],
            latitude: data["lat"],
            longitude: data["lon"],
            flight_level: data["fltLvl"],
            temperature_c: data["temp"],
            wind_direction_deg: data["wdir"],
            wind_speed_kt: data["wspd"],
            icing_intensity: blank_to_nil(data["icgInt1"]),
            icing_type: blank_to_nil(data["icgType1"]),
            icing_base_ft: data["icgBas1"] ? data["icgBas1"] * 100 : nil,
            icing_top_ft: data["icgTop1"] ? data["icgTop1"] * 100 : nil,
            turbulence_intensity: blank_to_nil(data["tbInt1"]),
            turbulence_type: blank_to_nil(data["tbType1"]),
            turbulence_base_ft: data["tbBas1"] ? data["tbBas1"] * 100 : nil,
            turbulence_top_ft: data["tbTop1"] ? data["tbTop1"] * 100 : nil
          )
        end

        def initialize(**attrs) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          @raw = attrs[:raw]
          @observed_at = attrs[:observed_at]
          @pirep_type = attrs[:pirep_type]
          @aircraft_type = attrs[:aircraft_type]
          @latitude = attrs[:latitude]
          @longitude = attrs[:longitude]
          @flight_level = attrs[:flight_level]
          @temperature_c = attrs[:temperature_c]
          @wind_direction_deg = attrs[:wind_direction_deg]
          @wind_speed_kt = attrs[:wind_speed_kt]
          @icing_intensity = attrs[:icing_intensity]
          @icing_type = attrs[:icing_type]
          @icing_base_ft = attrs[:icing_base_ft]
          @icing_top_ft = attrs[:icing_top_ft]
          @turbulence_intensity = attrs[:turbulence_intensity]
          @turbulence_type = attrs[:turbulence_type]
          @turbulence_base_ft = attrs[:turbulence_base_ft]
          @turbulence_top_ft = attrs[:turbulence_top_ft]
        end

        def position
          Skywatch::Shared::Position.new(lat: latitude, lon: longitude)
        end

        def altitude_ft
          flight_level ? flight_level * 100 : nil
        end

        def icing?
          !icing_intensity.nil?
        end

        def turbulence?
          !turbulence_intensity.nil?
        end

        def to_h # rubocop:disable Metrics/AbcSize
          {
            raw: raw, observed_at: observed_at&.iso8601, pirep_type: pirep_type,
            aircraft_type: aircraft_type, latitude: latitude, longitude: longitude,
            flight_level: flight_level, altitude_ft: altitude_ft,
            temperature_c: temperature_c,
            icing_intensity: icing_intensity, icing_type: icing_type,
            icing_base_ft: icing_base_ft, icing_top_ft: icing_top_ft,
            turbulence_intensity: turbulence_intensity, turbulence_type: turbulence_type,
            turbulence_base_ft: turbulence_base_ft, turbulence_top_ft: turbulence_top_ft
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        def self.blank_to_nil(value)
          return nil if value.nil? || (value.is_a?(String) && value.strip.empty?)

          value
        end

        private_class_method :blank_to_nil
      end
    end
  end
end
