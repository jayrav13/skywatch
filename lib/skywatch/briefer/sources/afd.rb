# frozen_string_literal: true

require 'uri'

module Skywatch
  module Briefer
    module Sources
      class Afd
        BASE_URL = 'https://api.weather.gov'
        TTL = 3600

        def initialize
          @client = Skywatch::Shared::Http.new(base_url: BASE_URL)
        end

        def fetch(wfo)
          list_path = "/products/types/AFD/locations/#{wfo.upcase}"
          list_data = @client.get(list_path, {}, ttl: TTL)
          entries = list_data['@graph']
          product_path = URI(entries.first['@id']).path
          product_data = @client.get(product_path, {}, ttl: TTL)
          Skywatch::Briefer::Models::Afd.from_nws(product_data)
        end
      end
    end
  end
end
