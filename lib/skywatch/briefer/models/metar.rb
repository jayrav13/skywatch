# frozen_string_literal: true

require 'json'
require 'time'

module Skywatch
  module Briefer
    module Models
      class Metar # rubocop:disable Metrics/ClassLength
        CEILING_COVERS = %i[bkn ovc].freeze
        HPA_TO_INHG = 0.02953

        attr_reader :raw, :station_id, :observed_at, :metar_type,
                    :wind_direction_deg, :wind_speed_kt, :wind_gust_kt,
                    :visibility_sm, :weather, :sky_condition,
                    :temperature_c, :dewpoint_c, :altimeter_inhg,
                    :station_name, :latitude, :longitude, :elevation_ft,
                    :sea_level_pressure_mb

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def self.from_awc(data)
          new(
            raw: data['rawOb'],
            station_id: data['icaoId'],
            observed_at: Time.at(data['obsTime']).utc,
            metar_type: data['metarType'],
            wind_direction_deg: data['wdir'],
            wind_speed_kt: data['wspd'],
            wind_gust_kt: data['wgst'],
            visibility_sm: parse_visibility(data['visib']),
            weather: parse_weather(data['wxString']),
            sky_condition: parse_clouds(data['clouds']),
            temperature_c: data['temp']&.to_f,
            dewpoint_c: data['dewp']&.to_f,
            altimeter_inhg: data['altim'] ? (data['altim'] * HPA_TO_INHG).round(2) : nil,
            station_name: data['name'],
            latitude: data['lat'],
            longitude: data['lon'],
            elevation_ft: data['elev'] ? (data['elev'] * 3.28084).round : nil,
            sea_level_pressure_mb: data['slp']
          )
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def initialize(**attrs)
          @raw = attrs[:raw]
          @station_id = attrs[:station_id]
          @observed_at = attrs[:observed_at]
          @metar_type = attrs[:metar_type]
          @wind_direction_deg = attrs[:wind_direction_deg]
          @wind_speed_kt = attrs[:wind_speed_kt]
          @wind_gust_kt = attrs[:wind_gust_kt]
          @visibility_sm = attrs[:visibility_sm]
          @weather = attrs[:weather]
          @sky_condition = attrs[:sky_condition]
          @temperature_c = attrs[:temperature_c]
          @dewpoint_c = attrs[:dewpoint_c]
          @altimeter_inhg = attrs[:altimeter_inhg]
          @station_name = attrs[:station_name]
          @latitude = attrs[:latitude]
          @longitude = attrs[:longitude]
          @elevation_ft = attrs[:elevation_ft]
          @sea_level_pressure_mb = attrs[:sea_level_pressure_mb]
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def position
          Skywatch::Shared::Position.new(lat: latitude, lon: longitude)
        end

        def ceiling_ft
          ceiling_layer = sky_condition&.find { |layer| CEILING_COVERS.include?(layer[:cover]) }
          ceiling_layer&.dig(:base_ft)
        end

        def flight_category
          Skywatch::Briefer::Analysis::FlightCategory.classify(ceiling_ft: ceiling_ft, visibility_sm: visibility_sm)
        end

        def spread_c
          return nil unless temperature_c && dewpoint_c

          (temperature_c - dewpoint_c).round(1)
        end

        def density_altitude_ft
          return nil unless temperature_c && altimeter_inhg && elevation_ft

          pressure_alt = elevation_ft + ((29.92 - altimeter_inhg) * 1000)
          isa_temp = 15.0 - (elevation_ft * 0.002)
          (pressure_alt + (120 * (temperature_c - isa_temp))).round
        end

        def vfr? = flight_category == :vfr
        def mvfr? = flight_category == :mvfr
        def ifr? = flight_category == :ifr
        def lifr? = flight_category == :lifr

        # rubocop:disable Metrics/AbcSize
        def to_h
          {
            station_id: station_id, raw: raw, observed_at: observed_at&.iso8601, metar_type: metar_type,
            wind_direction_deg: wind_direction_deg, wind_speed_kt: wind_speed_kt, wind_gust_kt: wind_gust_kt,
            visibility_sm: visibility_sm, weather: weather, sky_condition: sky_condition,
            temperature_c: temperature_c, dewpoint_c: dewpoint_c, altimeter_inhg: altimeter_inhg,
            station_name: station_name, latitude: latitude, longitude: longitude, elevation_ft: elevation_ft,
            ceiling_ft: ceiling_ft, flight_category: flight_category, spread_c: spread_c,
            density_altitude_ft: density_altitude_ft
          }
        end
        # rubocop:enable Metrics/AbcSize

        def to_json(*)
          to_h.to_json(*)
        end

        def self.parse_visibility(visib)
          return nil if visib.nil?

          visib = visib.to_s.gsub('+', '')
          if visib.include?('/')
            parts = visib.split('/')
            parts[0].to_f / parts[1].to_i
          else
            visib.to_f
          end
        end

        def self.parse_weather(wx_string)
          return [] if wx_string.nil? || wx_string.strip.empty?

          wx_string.strip.split
        end

        def self.parse_clouds(clouds)
          return [] if clouds.nil?

          clouds.map do |cloud|
            { cover: cloud['cover']&.downcase&.to_sym, base_ft: cloud['base'] }
          end
        end

        private_class_method :parse_visibility, :parse_weather, :parse_clouds
      end
    end
  end
end
