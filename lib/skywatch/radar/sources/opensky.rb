# frozen_string_literal: true

module Skywatch
  module Radar
    module Sources
      class Opensky
        ENDPOINT = '/api/states/all'
        TTL = 15

        def initialize
          http = Skywatch::Shared::Http.new(base_url: 'https://opensky-network.org')
          @client = Skywatch::Shared::Cache.new(client: http)
        end

        def states_bbox(lamin:, lamax:, lomin:, lomax:)
          data = @client.get(ENDPOINT, {
                               lamin: lamin.to_s, lamax: lamax.to_s,
                               lomin: lomin.to_s, lomax: lomax.to_s
                             }, ttl: TTL)
          parse_states(data)
        end

        def states_by_callsign(callsign)
          data = @client.get(ENDPOINT, {}, ttl: TTL)
          parse_states(data).select { |sv| sv.callsign&.upcase == callsign.upcase }
        end

        def states_by_icao24(icao24)
          data = @client.get(ENDPOINT, { icao24: icao24.downcase }, ttl: TTL)
          parse_states(data)
        end

        private

        def parse_states(data)
          return [] if data['states'].nil?

          data['states'].map { |row| Models::StateVector.from_api(row) }
        end
      end
    end
  end
end
