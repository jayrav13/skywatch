# frozen_string_literal: true

module Skywatch
  module Brief
    module Analysis
      module AirportLocator
        WFO_TTL = 86_400

        def self.coordinates_from_metar(metar)
          raise Skywatch::Error, "no coordinates on METAR for #{metar.station_id}" if
            metar.latitude.nil? || metar.longitude.nil?

          [metar.latitude, metar.longitude]
        end

        def self.wfo_for(lat, lon)
          data = points_client.get("/points/#{lat},#{lon}", {}, ttl: WFO_TTL)
          cwa = data.dig('properties', 'cwa')
          raise Skywatch::Error, "no WFO on /points response for #{lat},#{lon}" if cwa.nil? || cwa.empty?

          cwa
        rescue Skywatch::ApiError => e
          raise Skywatch::Error, "WFO lookup failed for #{lat},#{lon}: #{e.message}"
        end

        def self.points_client
          @points_client ||= Skywatch::Shared::Cache.new(
            client: Skywatch::Shared::Http.new(base_url: 'https://api.weather.gov')
          )
        end

        def self.reset!
          @points_client = nil
        end
      end
    end
  end
end
