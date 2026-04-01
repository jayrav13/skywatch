# frozen_string_literal: true

module Skywatch
  module Radar
    module Formatters
      module Text
        HEADER = '  %-10s %7s %6s %5s %7s'
        ROW    = '  %-10s %7s %6s %5s %7s'

        def self.format_flights_table(state_vectors, label:)
          return "No flights found near #{label}\n" if state_vectors.empty?

          lines = ["Flights near #{label} — #{state_vectors.size} aircraft\n"]
          lines << "#{format(HEADER, 'CALL', 'ALT', 'SPD', 'HDG', 'SQUAWK')}\n"
          state_vectors.each { |sv| lines << format_flight_row(sv) }
          lines.join
        end

        def self.format_flight_row(sv) # rubocop:disable Naming/MethodParameterName
          call = sv.callsign || sv.icao24
          alt = sv.altitude_ft ? "#{number_with_commas(sv.altitude_ft)}'" : 'GND'
          spd = sv.velocity_kt ? "#{sv.velocity_kt}kt" : '-'
          hdg = sv.true_track_deg ? "#{sv.true_track_deg.round}°" : '-'
          sqk = sv.squawk || '-'
          "#{format(ROW, call, alt, spd, hdg, sqk)}\n"
        end

        def self.format_track(sv) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Naming/MethodParameterName
          call = sv.callsign || sv.icao24
          alt = sv.altitude_ft ? "#{number_with_commas(sv.altitude_ft)} ft" : 'On ground'
          spd = sv.velocity_kt ? "#{sv.velocity_kt} kt" : '-'
          hdg = sv.true_track_deg ? "#{sv.true_track_deg.round}°" : '-'
          vr = sv.vertical_rate_fpm ? "#{sv.vertical_rate_fpm} fpm" : '-'
          desc = if sv.vertical_rate_fpm&.negative?
                   ' (descending)'
                 else
                   (sv.vertical_rate_fpm&.positive? ? ' (climbing)' : '')
                 end

          <<~TEXT
            #{call} — #{sv.origin_country}
              Position:  #{sv.latitude}°N, #{sv.longitude}°W
              Altitude:  #{alt}
              Speed:     #{spd}, heading #{hdg}
              Vertical:  #{vr}#{desc}
              Squawk:    #{sv.squawk || '-'}
              On ground: #{sv.on_ground ? 'Yes' : 'No'}
          TEXT
        end

        def self.number_with_commas(number)
          number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
        end

        private_class_method :number_with_commas
      end
    end
  end
end
