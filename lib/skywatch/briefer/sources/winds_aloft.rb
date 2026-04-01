# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class WindsAloft
        ENDPOINT = '/api/data/windtemp'
        TTL = 3600
        ALTITUDE_COLUMNS = {
          3000 => 'ft_3000', 6000 => 'ft_6000', 9000 => 'ft_9000',
          12_000 => 'ft_12000', 18_000 => 'ft_18000', 24_000 => 'ft_24000',
          30_000 => 'ft_30000', 34_000 => 'ft_34000', 39_000 => 'ft_39000'
        }.freeze

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch(station_id, altitude_ft: nil)
          data = @client.get(ENDPOINT, { region: 'all', level: 'low', fcst: '06', format: 'json' }, ttl: TTL)
          station_data = data.find { |entry| entry['station_id']&.upcase == station_id.upcase }
          return [] unless station_data

          columns = altitude_ft ? { altitude_ft => ALTITUDE_COLUMNS[altitude_ft] } : ALTITUDE_COLUMNS

          columns.filter_map do |alt, col|
            encoded = station_data[col]
            Skywatch::Briefer::Models::WindsAloft.decode(station_id: station_data['station_id'], altitude_ft: alt,
                                                         encoded: encoded)
          end
        end
      end
    end
  end
end
