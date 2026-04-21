# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Sources
      class Outlook
        BASE_URL = 'https://www.spc.noaa.gov'
        TTL = 3600
        VALID_DAYS = [1, 2, 3].freeze

        def initialize(client: default_client)
          @client = client
        end

        def fetch(day:)
          raise ArgumentError, "day must be 1, 2, or 3 (got #{day.inspect})" unless VALID_DAYS.include?(day)

          data = @client.get("/products/outlook/day#{day}otlk_cat.lyr.geojson", {}, ttl: TTL)
          features = data['features'] || []
          features.map { |f| Skywatch::Nimbus::Models::Outlook.from_spc_feature(f, day: day) }
        end

        private

        def default_client
          Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
        end
      end
    end
  end
end
