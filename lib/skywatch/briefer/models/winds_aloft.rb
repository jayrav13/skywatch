# frozen_string_literal: true

module Skywatch
  module Briefer
    module Models
      class WindsAloft
        attr_reader :station_id, :altitude_ft, :wind_direction_deg, :wind_speed_kt,
                    :temperature_c, :light_and_variable

        def self.decode(station_id:, altitude_ft:, encoded:)
          return nil if encoded.nil? || encoded.strip.empty?

          direction, speed, temp = parse_encoded(encoded, altitude_ft)

          new(
            station_id: station_id,
            altitude_ft: altitude_ft,
            wind_direction_deg: direction,
            wind_speed_kt: speed,
            temperature_c: temp,
            light_and_variable: direction.nil? && speed.nil? && encoded.start_with?('99')
          )
        end

        def initialize(**attrs)
          @station_id = attrs[:station_id]
          @altitude_ft = attrs[:altitude_ft]
          @wind_direction_deg = attrs[:wind_direction_deg]
          @wind_speed_kt = attrs[:wind_speed_kt]
          @temperature_c = attrs[:temperature_c]
          @light_and_variable = attrs[:light_and_variable] || false
        end

        def light_and_variable?
          @light_and_variable
        end

        def to_h
          {
            station_id: station_id, altitude_ft: altitude_ft,
            wind_direction_deg: wind_direction_deg, wind_speed_kt: wind_speed_kt,
            temperature_c: temperature_c, light_and_variable: light_and_variable?
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end

        def self.parse_encoded(encoded, altitude_ft) # rubocop:disable Metrics/MethodLength
          wind_part = encoded[0, 4]
          temp_part = encoded[4..]

          dir_code = wind_part[0, 2].to_i
          speed = wind_part[2, 2].to_i

          # Light and variable
          if dir_code == 99 && speed.zero?
            temp = parse_temp(temp_part, altitude_ft)
            return [nil, nil, temp]
          end

          # High speed encoding: direction > 36 means subtract 50, add 100 to speed
          if dir_code > 36
            dir_code -= 50
            speed += 100
          end

          direction = dir_code * 10
          temp = parse_temp(temp_part, altitude_ft)

          [direction, speed, temp]
        end

        def self.parse_temp(temp_part, altitude_ft)
          return nil if temp_part.nil? || temp_part.strip.empty?

          if temp_part.match?(/^[+-]/)
            temp_part.to_i
          else
            temp = temp_part.to_i
            altitude_ft >= 24_000 ? -temp : temp
          end
        end

        private_class_method :parse_encoded, :parse_temp
      end
    end
  end
end
