# frozen_string_literal: true

require_relative "briefer/version"
require_relative "briefer/errors"
require_relative "briefer/client/http"
require_relative "briefer/client/cache"
require_relative "briefer/models/position"
require_relative "briefer/models/metar"
require_relative "briefer/models/taf_group"
require_relative "briefer/models/taf"
require_relative "briefer/analysis/flight_category"
require_relative "briefer/sources/metar"
require_relative "briefer/sources/taf"
require_relative "briefer/formatters/text"

module Briefer
  class << self
    def client
      @client ||= Client::Cache.new(client: Client::Http.new)
    end

    def reset!
      @client = nil
    end

    def metar(*station_ids)
      Sources::Metar.new.fetch(*station_ids)
    end

    def taf(*station_ids)
      Sources::Taf.new.fetch(*station_ids)
    end
  end
end

require_relative "briefer/cli"
