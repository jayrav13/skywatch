# frozen_string_literal: true

require 'csv'
require 'date'

module Skywatch
  module Nimbus
    module Sources
      class StormReport
        BASE_URL = 'https://www.spc.noaa.gov'
        TTL = 300
        SECTION_HEADERS = {
          'F_Scale' => :tornado,
          'Speed'   => :wind,
          'Size'    => :hail
        }.freeze

        def initialize(client: default_client)
          @client = client
        end

        def fetch(date: nil)
          path = date ? "/climo/reports/#{date.strftime('%y%m%d')}.csv" : '/climo/reports/today.csv'
          report_date = date || Date.today
          body = @client.get_raw(path, {}, ttl: TTL)
          parse_sections(body, report_date: report_date)
        end

        private

        def parse_sections(body, report_date:)
          current_type = nil
          reports = []

          CSV.parse(body) do |row|
            next if row.nil? || row.empty?

            type_for_header = section_for_header(row)
            if type_for_header
              current_type = type_for_header
              next
            end

            next if current_type.nil?

            reports << Skywatch::Nimbus::Models::StormReport.from_spc_row(
              row, type: current_type, report_date: report_date
            )
          end

          reports
        end

        def section_for_header(row)
          return nil if row.length < 2

          SECTION_HEADERS[row[1]]
        end

        def default_client
          Skywatch::Shared::Cache.new(client: Skywatch::Shared::Http.new(base_url: BASE_URL))
        end
      end
    end
  end
end
