# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Briefer
  module Client
    class Http
      BASE_URL = "https://aviationweather.gov"

      attr_reader :connection

      def initialize
        @connection = build_connection
      end

      def get(path, params = {}, ttl: nil) # rubocop:disable Lint/UnusedMethodArgument
        response = connection.get(path, params)
        raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

        JSON.parse(response.body)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise ConnectionError, e.message
      rescue JSON::ParserError => e
        raise ParseError, e.message
      end

      private

      def build_connection
        Faraday.new(url: BASE_URL) do |f|
          f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
          f.headers["User-Agent"] = "Briefer/#{Briefer::VERSION} (ruby; github.com/jay/briefer)"
          f.options.open_timeout = 10
          f.options.timeout = 10
        end
      end
    end
  end
end
