# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class Metar
        ENDPOINT = '/api/data/metar'
        TTL = 300
        DEFAULT_NEAREST_RADIUS_NM = 100

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch(*station_ids)
          ids = station_ids.map(&:upcase).join(',')
          data = @client.get(ENDPOINT, { ids: ids, format: 'json' }, ttl: TTL)
          data.map { |entry| Skywatch::Briefer::Models::Metar.from_awc(entry) }
        end

        def fetch_nearest(lat:, lon:, radius_nm: DEFAULT_NEAREST_RADIUS_NM)
          metars = fetch_in_bbox(lat: lat, lon: lon, radius_nm: radius_nm)
          return nil if metars.empty?

          metars.min_by { |m| Skywatch::Radar::Analysis::Proximity.distance_nm(lat, lon, m.latitude, m.longitude) }
        end

        private

        def fetch_in_bbox(lat:, lon:, radius_nm:)
          box = Skywatch::Radar::Analysis::Proximity.bbox(lat, lon, radius_nm: radius_nm)
          bbox_param = "#{box[:lamin]},#{box[:lomin]},#{box[:lamax]},#{box[:lomax]}"
          data = @client.get(ENDPOINT, { bbox: bbox_param, format: 'json' }, ttl: TTL)
          data.map { |entry| Skywatch::Briefer::Models::Metar.from_awc(entry) }
              .reject { |m| m.latitude.nil? || m.longitude.nil? }
        end
      end
    end
  end
end
