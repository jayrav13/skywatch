# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Sources
      class Alerts
        BASE_URL = 'https://api.weather.gov'
        TTL = 60

        EVENTS = [
          'Tornado Warning',
          'Severe Thunderstorm Warning',
          'Flash Flood Warning',
          'Tornado Watch',
          'Severe Thunderstorm Watch'
        ].freeze

        def initialize(client: default_client)
          @client = client
        end

        def fetch(at:, events: EVENTS)
          raise ArgumentError, 'events must be non-empty' if events.empty?

          lat, lon = at
          params = { point: "#{lat},#{lon}", event: events.join(',') }
          data = @client.get('/alerts/active', params, ttl: TTL)
          features = data['features'] || []
          features.map { |f| Models::ConvectiveAlert.from_nws_feature(f) }
        end

        private

        def default_client
          Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
        end
      end
    end
  end
end
