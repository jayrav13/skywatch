# frozen_string_literal: true

module Briefer
  module Sources
    class Pirep
      ENDPOINT = "/api/data/pirep"
      TTL = 600

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(station_id, radius_nm: 100)
        data = @client.get(ENDPOINT, { id: station_id.upcase, dist: radius_nm.to_s, format: "json" }, ttl: TTL)
        data.map { |entry| Models::Pirep.from_awc(entry) }
      end
    end
  end
end
