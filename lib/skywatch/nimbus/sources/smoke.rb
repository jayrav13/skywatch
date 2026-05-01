# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Sources
      class Smoke
        BASE_URL = 'https://services2.arcgis.com'
        PATH = '/C8EMgrsFcRFL6LrL/arcgis/rest/services/' \
               'NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query'
        TTL = 3600

        def initialize(client: default_client)
          @client = client
        end

        def fetch(at:)
          lat, lon = at
          data = @client.get(PATH, query_params(lat, lon), ttl: TTL)
          features = data['features'] || []
          features.map { |f| Models::Smoke.from_arcgis_feature(f) }
        end

        private

        def query_params(lat, lon)
          {
            geometry: "#{lon},#{lat}",
            geometryType: 'esriGeometryPoint',
            inSR: 4326,
            spatialRel: 'esriSpatialRelIntersects',
            outFields: '*',
            f: 'json'
          }
        end

        def default_client
          Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
        end
      end
    end
  end
end
