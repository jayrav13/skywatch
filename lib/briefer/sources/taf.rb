# frozen_string_literal: true

module Briefer
  module Sources
    class Taf
      ENDPOINT = "/api/data/taf"
      TTL = 1800

      def initialize(client: Briefer.client)
        @client = client
      end

      def fetch(*station_ids)
        ids = station_ids.map(&:upcase).join(",")
        data = @client.get(ENDPOINT, { ids: ids, format: "json" }, ttl: TTL)
        data.map { |entry| Models::Taf.from_awc(entry) }
      end
    end
  end
end
