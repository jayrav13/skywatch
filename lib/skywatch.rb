# frozen_string_literal: true

require_relative "skywatch/version"
require_relative "skywatch/shared/errors"
require_relative "skywatch/shared/position"
require_relative "skywatch/shared/http"
require_relative "skywatch/shared/cache"
require_relative "skywatch/shared/geometry"
require_relative "skywatch/briefer/models/metar"
require_relative "skywatch/briefer/models/taf_group"
require_relative "skywatch/briefer/models/taf"
require_relative "skywatch/briefer/models/pirep"
require_relative "skywatch/briefer/models/winds_aloft"
require_relative "skywatch/briefer/models/sigmet"
require_relative "skywatch/briefer/models/airmet"
require_relative "skywatch/briefer/models/tfr"
require_relative "skywatch/briefer/analysis/flight_category"
require_relative "skywatch/briefer/analysis/crosswind_calculator"

module Skywatch
  class << self
    def client
      @client ||= Shared::Cache.new(client: Shared::Http.new)
    end

    def reset!
      @client = nil
    end
  end
end
