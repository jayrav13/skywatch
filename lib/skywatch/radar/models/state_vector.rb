# frozen_string_literal: true

module Skywatch
  module Radar
    module Models
      class StateVector
        METERS_TO_FEET = 3.28084
        MS_TO_KNOTS = 1.94384
        MS_TO_FPM = 196.85

        EMERGENCY_SQUAWKS = %w[7500 7600 7700].freeze

        attr_reader :icao24, :callsign, :origin_country,
                    :time_position, :last_contact,
                    :longitude, :latitude, :baro_altitude_m,
                    :on_ground, :velocity_ms, :true_track_deg,
                    :vertical_rate_ms, :geo_altitude_m,
                    :squawk, :spi

        def self.from_api(row) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          new(
            icao24: row[0],
            callsign: row[1]&.strip&.then { |s| s.empty? ? nil : s },
            origin_country: row[2],
            time_position: row[3],
            last_contact: row[4],
            longitude: row[5]&.to_f,
            latitude: row[6]&.to_f,
            baro_altitude_m: row[7]&.to_f,
            on_ground: row[8],
            velocity_ms: row[9]&.to_f,
            true_track_deg: row[10]&.to_f,
            vertical_rate_ms: row[11]&.to_f,
            geo_altitude_m: row[13]&.to_f,
            squawk: row[14],
            spi: row[15] || false
          )
        end

        def initialize(**attrs) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          @icao24 = attrs[:icao24]
          @callsign = attrs[:callsign]
          @origin_country = attrs[:origin_country]
          @time_position = attrs[:time_position]
          @last_contact = attrs[:last_contact]
          @longitude = attrs[:longitude]
          @latitude = attrs[:latitude]
          @baro_altitude_m = attrs[:baro_altitude_m]
          @on_ground = attrs[:on_ground]
          @velocity_ms = attrs[:velocity_ms]
          @true_track_deg = attrs[:true_track_deg]
          @vertical_rate_ms = attrs[:vertical_rate_ms]
          @geo_altitude_m = attrs[:geo_altitude_m]
          @squawk = attrs[:squawk]
          @spi = attrs[:spi]
        end

        def altitude_ft
          return nil if baro_altitude_m.nil?

          (baro_altitude_m * METERS_TO_FEET).round
        end

        def velocity_kt
          return nil if velocity_ms.nil?

          (velocity_ms * MS_TO_KNOTS).round
        end

        def vertical_rate_fpm
          return nil if vertical_rate_ms.nil?

          (vertical_rate_ms * MS_TO_FPM).round
        end

        def emergency?
          EMERGENCY_SQUAWKS.include?(squawk)
        end

        def to_h
          {
            icao24: icao24, callsign: callsign, origin_country: origin_country,
            latitude: latitude, longitude: longitude,
            altitude_ft: altitude_ft, on_ground: on_ground,
            velocity_kt: velocity_kt, true_track_deg: true_track_deg,
            vertical_rate_fpm: vertical_rate_fpm,
            squawk: squawk, emergency: emergency?
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
