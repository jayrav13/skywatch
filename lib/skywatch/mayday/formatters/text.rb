# frozen_string_literal: true

module Skywatch
  module Mayday
    module Formatters
      module Text
        def self.format_emergency(emergency)
          alt = format_altitude(emergency.altitude_ft)
          spd = emergency.velocity_kt ? "#{emergency.velocity_kt}kt" : '---'
          hdg = format_heading(emergency.heading_deg)
          pos = format_position(emergency.latitude, emergency.longitude)

          <<~TEXT
            MAYDAY: #{emergency.label} (squawk #{emergency.squawk})
              Callsign: #{emergency.callsign || '---'}   ICAO24: #{emergency.icao24}
              Position: #{pos}   Alt: #{alt}   Spd: #{spd}   Hdg: #{hdg}
          TEXT
        end

        def self.format_altitude(altitude_ft)
          return '---' if altitude_ft.nil?

          format('FL%03d', (altitude_ft / 100.0).round)
        end

        def self.format_heading(heading_deg)
          return '---' if heading_deg.nil?

          format('%03d°', heading_deg.round)
        end

        def self.format_position(lat, lon)
          return '---' if lat.nil? || lon.nil?

          format('%<lat>.4f, %<lon>.4f', lat: lat, lon: lon)
        end

        private_class_method :format_altitude, :format_heading, :format_position
      end
    end
  end
end
