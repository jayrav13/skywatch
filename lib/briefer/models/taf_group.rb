# frozen_string_literal: true

module Briefer
  module Models
    class TafGroup
      CEILING_COVERS = %i[bkn ovc].freeze
      CHANGE_TYPES = { nil => :initial, "FM" => :fm, "BECMG" => :becmg, "TEMPO" => :tempo, "PROB" => :prob }.freeze

      attr_reader :time_from, :time_to, :change_type, :probability,
                  :wind_direction_deg, :wind_speed_kt, :wind_gust_kt,
                  :visibility_sm, :weather, :sky_condition

      def self.from_awc(data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        new(
          time_from: Time.at(data["timeFrom"]).utc,
          time_to: Time.at(data["timeTo"]).utc,
          change_type: CHANGE_TYPES.fetch(data["fcstChange"], :initial),
          probability: data["probability"],
          wind_direction_deg: data["wdir"],
          wind_speed_kt: data["wspd"],
          wind_gust_kt: data["wgst"],
          visibility_sm: Metar.send(:parse_visibility, data["visib"]),
          weather: Metar.send(:parse_weather, data["wxString"]),
          sky_condition: Metar.send(:parse_clouds, data["clouds"])
        )
      end

      def initialize(**attrs)
        @time_from = attrs[:time_from]
        @time_to = attrs[:time_to]
        @change_type = attrs[:change_type]
        @probability = attrs[:probability]
        @wind_direction_deg = attrs[:wind_direction_deg]
        @wind_speed_kt = attrs[:wind_speed_kt]
        @wind_gust_kt = attrs[:wind_gust_kt]
        @visibility_sm = attrs[:visibility_sm]
        @weather = attrs[:weather]
        @sky_condition = attrs[:sky_condition]
      end

      def ceiling_ft
        ceiling_layer = sky_condition&.find { |layer| CEILING_COVERS.include?(layer[:cover]) }
        ceiling_layer&.dig(:base_ft)
      end

      def flight_category
        Analysis::FlightCategory.classify(ceiling_ft: ceiling_ft, visibility_sm: visibility_sm)
      end

      def to_h
        {
          time_from: time_from&.iso8601, time_to: time_to&.iso8601,
          change_type: change_type, probability: probability,
          wind_direction_deg: wind_direction_deg, wind_speed_kt: wind_speed_kt, wind_gust_kt: wind_gust_kt,
          visibility_sm: visibility_sm, weather: weather, sky_condition: sky_condition,
          ceiling_ft: ceiling_ft, flight_category: flight_category
        }
      end

      def to_json(*)
        to_h.to_json(*)
      end
    end
  end
end
