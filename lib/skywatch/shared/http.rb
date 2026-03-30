# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Skywatch
  module Shared
    class Http
      DEFAULT_BASE_URL = "https://aviationweather.gov"

      attr_reader :connection

      def initialize(base_url: DEFAULT_BASE_URL)
        @connection = build_connection(base_url)
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

      def get_raw(path, params = {}, ttl: nil) # rubocop:disable Lint/UnusedMethodArgument
        response = connection.get(path, params)
        raise ApiError.new("HTTP #{response.status}", response: response) unless response.success?

        response.body
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        raise ConnectionError, e.message
      end

      private

      def build_connection(base_url)
        Faraday.new(url: base_url) do |f|
          f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
          f.headers["User-Agent"] = "Skywatch/#{Skywatch::VERSION} (ruby; github.com/jayrav13/skywatch)"
          f.options.open_timeout = 10
          f.options.timeout = 30
        end
      end
    end
  end
end
