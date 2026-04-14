# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class Airmet
        ENDPOINT = '/api/data/gairmet'
        TTL = 900

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch
          data = @client.get(ENDPOINT, { format: 'json' }, ttl: TTL)
          data.map { |entry| Skywatch::Briefer::Models::Airmet.from_awc(entry) }
        end
      end
    end
  end
end
