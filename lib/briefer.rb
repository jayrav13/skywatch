# frozen_string_literal: true

require_relative "briefer/version"
require_relative "briefer/errors"
require_relative "briefer/client/http"
require_relative "briefer/client/cache"
require_relative "briefer/models/position"
require_relative "briefer/models/metar"
require_relative "briefer/models/taf_group"
require_relative "briefer/models/taf"
require_relative "briefer/models/pirep"
require_relative "briefer/models/winds_aloft"
require_relative "briefer/analysis/flight_category"
require_relative "briefer/analysis/crosswind_calculator"
require_relative "briefer/sources/metar"
require_relative "briefer/sources/taf"
require_relative "briefer/sources/pirep"
require_relative "briefer/sources/winds_aloft"
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

    def pireps(station_id, radius_nm: 100)
      Sources::Pirep.new.fetch(station_id, radius_nm: radius_nm)
    end

    def winds_aloft(station_id, altitude_ft: nil)
      Sources::WindsAloft.new.fetch(station_id, altitude_ft: altitude_ft)
    end

    def crosswind(station_id, runway_heading:)
      metars = metar(station_id)
      raise Error, "No METAR available for #{station_id}" if metars.empty?

      m = metars.first
      Analysis::CrosswindCalculator.calculate(
        wind_direction_deg: m.wind_direction_deg || 0,
        wind_speed_kt: m.wind_speed_kt || 0,
        runway_heading: runway_heading
      )
    end
  end
end

require_relative "briefer/cli"
