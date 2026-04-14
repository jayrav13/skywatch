# frozen_string_literal: true

module Skywatch
  module Briefer
    module Formatters
      module Text
        def self.format_metar(metar)
          <<~TEXT
            #{metar.station_id} (#{metar.station_name}) — #{metar.flight_category.upcase}
              #{metar.raw}
              Ceiling: #{format_ceiling(metar)}  Vis: #{format_visibility(metar.visibility_sm)}  Wind: #{format_wind(metar)}
              Temp: #{metar.temperature_c}°C  Dew: #{metar.dewpoint_c}°C  Spread: #{metar.spread_c}°C  Altimeter: #{metar.altimeter_inhg}
          TEXT
        end

        def self.format_ceiling(metar)
          return '-' unless metar.ceiling_ft

          cover = metar.sky_condition&.find { |l| %i[bkn ovc].include?(l[:cover]) }
          label = cover ? " (#{cover[:cover].upcase})" : ''
          "#{number_with_commas(metar.ceiling_ft)}'#{label}"
        end

        def self.format_category(metar)
          "#{metar.station_id} — #{metar.flight_category.upcase}\n"
        end

        def self.format_wind(metar)
          wind = "#{metar.wind_direction_deg}° @ #{metar.wind_speed_kt}kt"
          wind += "G#{metar.wind_gust_kt}kt" if metar.wind_gust_kt
          wind
        end

        def self.format_visibility(vis)
          return '-' if vis.nil?

          vis >= 10 ? '10+SM' : "#{vis}SM"
        end

        def self.number_with_commas(number)
          number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
        end

        def self.format_taf(taf) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          lines = ["#{taf.station_id} (#{taf.station_name}) — TAF issued #{taf.issued_at.strftime('%d %b %Y %H%MZ')}\n"]
          lines << "  #{taf.raw}\n"
          taf.forecast_groups.each do |group|
            prefix = group.change_type == :initial ? '  ' : "  #{group.change_type.upcase} "
            from = group.time_from.strftime('%H%MZ')
            to = group.time_to.strftime('%H%MZ')
            wind = "#{group.wind_direction_deg}°@#{group.wind_speed_kt}kt"
            wind += "G#{group.wind_gust_kt}" if group.wind_gust_kt
            vis = group.visibility_sm && group.visibility_sm >= 6 ? 'P6SM' : "#{group.visibility_sm}SM"
            clouds = format_taf_clouds(group.sky_condition)
            lines << "#{prefix}#{from}-#{to}: #{wind} #{vis} #{clouds} [#{group.flight_category.upcase}]\n"
          end
          lines.join
        end

        def self.format_taf_clouds(sky_condition)
          sky_condition.map do |c|
            base = c[:base_ft] ? format('%03d', c[:base_ft] / 100) : ''
            "#{c[:cover].upcase}#{base}"
          end.join(' ')
        end

        def self.format_pirep(pirep)
          parts = ["#{pirep.aircraft_type} FL#{format('%03d', pirep.flight_level || 0)}"]
          parts << "IC:#{pirep.icing_intensity} #{pirep.icing_type}" if pirep.icing?
          parts << "TB:#{pirep.turbulence_intensity}" if pirep.turbulence?
          parts << "Temp:#{pirep.temperature_c}°C" if pirep.temperature_c
          "  #{parts.join('  ')}  (#{pirep.observed_at.strftime('%H%MZ')})\n"
        end

        def self.format_winds_aloft(winds) # rubocop:disable Metrics/MethodLength
          return "No winds aloft data available\n" if winds.empty?

          lines = [winds_aloft_row('Alt', 'Dir', 'Speed', 'Temp')]
          winds.each do |w|
            alt = "#{number_with_commas(w.altitude_ft)}'"
            temp = w.temperature_c ? "#{w.temperature_c}°C" : '-'
            lines << if w.light_and_variable?
                       winds_aloft_row(alt, 'VRB', 'LGT', temp)
                     else
                       winds_aloft_row(alt, "#{w.wind_direction_deg}°", "#{w.wind_speed_kt}kt", temp)
                     end
          end
          lines.join
        end

        def self.winds_aloft_row(alt, dir, speed, temp)
          "  #{alt.ljust(8)} #{dir.ljust(10)} #{speed.ljust(8)} #{temp}\n"
        end

        def self.format_sigmet(sigmet) # rubocop:disable Metrics/AbcSize
          lines = []
          lines << "[#{sigmet.sigmet_type.to_s.upcase}] #{sigmet.series_id} — #{sigmet.hazard}"
          lines << "  Issuing center: #{sigmet.issuing_center}"
          lines << "  Altitude: #{format_altitude_band(sigmet.altitude_low_ft, sigmet.altitude_hi_ft)}"
          from = sigmet.valid_from&.strftime('%d %b %H%MZ')
          to   = sigmet.valid_to&.strftime('%d %b %H%MZ')
          lines << "  Valid: #{from} \u2013 #{to}"
          lines << "  #{sigmet.raw}" if sigmet.raw
          "#{lines.join("\n")}\n"
        end

        def self.format_altitude_band(low_ft, hi_ft)
          low = low_ft ? "#{number_with_commas(low_ft)}'" : 'SFC'
          hi  = hi_ft  ? "#{number_with_commas(hi_ft)}'"  : 'UNL'
          "#{low} – #{hi}"
        end

        def self.format_crosswind(result, station_id, runway_heading)
          tailwind = result[:headwind_kt].negative?
          hw_label = tailwind ? 'Tailwind' : 'Headwind'
          "#{station_id} Runway #{runway_heading}°: Crosswind #{result[:crosswind_kt]}kt, " \
            "#{hw_label} #{result[:headwind_kt].abs}kt\n"
        end

        private_class_method :format_wind, :format_visibility, :format_ceiling, :number_with_commas,
                             :format_taf_clouds, :winds_aloft_row, :format_altitude_band
      end
    end
  end
end
