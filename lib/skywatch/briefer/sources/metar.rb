# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class Metar
        ENDPOINT = '/api/data/metar'
        TTL = 300

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch(*station_ids)
          ids = station_ids.map(&:upcase).join(',')
          data = @client.get(ENDPOINT, { ids: ids, format: 'json' }, ttl: TTL)
          data.map { |entry| Skywatch::Briefer::Models::Metar.from_awc(entry) }
        end
      end
    end
  end
end
