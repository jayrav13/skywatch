# frozen_string_literal: true

module Skywatch
  module Briefer
    module Sources
      class WindsAloft
        ENDPOINT = '/api/data/windtemp'
        TTL = 3600

        COLUMNS = [
          [3000,  4,  4],
          [6000,  9,  7],
          [9000,  17, 7],
          [12_000, 25, 7],
          [18_000, 33, 7],
          [24_000, 41, 7],
          [30_000, 49, 6],
          [34_000, 56, 6],
          [39_000, 63, 6]
        ].freeze

        def initialize(client: Skywatch.client)
          @client = client
        end

        def fetch(station_id, altitude_ft: nil)
          body = @client.get_raw(ENDPOINT, { region: 'all', level: 'low', fcst: '06', format: 'json' }, ttl: TTL)
          line = find_station_line(body, station_id)
          return [] unless line

          rows_for(line, station_id, altitude_ft)
        end

        private

        def find_station_line(body, station_id)
          target = station_id.upcase
          body.each_line.find do |l|
            l[0, 3] == target && l.length > 4
          end
        end

        def rows_for(line, station_id, altitude_ft)
          COLUMNS.filter_map do |alt, start, len|
            next if altitude_ft && alt != altitude_ft

            cell = line[start, len].to_s.strip
            next if cell.empty?

            Skywatch::Briefer::Models::WindsAloft.decode(
              station_id: station_id.upcase, altitude_ft: alt, encoded: cell
            )
          end
        end
      end
    end
  end
end
