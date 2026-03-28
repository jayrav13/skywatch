# frozen_string_literal: true

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
        return "-" unless metar.ceiling_ft

        cover = metar.sky_condition&.find { |l| %i[bkn ovc].include?(l[:cover]) }
        label = cover ? " (#{cover[:cover].upcase})" : ""
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
        return "-" if vis.nil?

        vis >= 10 ? "10+SM" : "#{vis}SM"
      end

      def self.number_with_commas(number)
        number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end

      private_class_method :format_wind, :format_visibility, :format_ceiling, :number_with_commas
    end
  end
end
