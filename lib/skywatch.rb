# frozen_string_literal: true

require_relative 'skywatch/version'
require_relative 'skywatch/shared/errors'
require_relative 'skywatch/shared/position'
require_relative 'skywatch/shared/http'
require_relative 'skywatch/shared/cache'
require_relative 'skywatch/shared/geometry'
require_relative 'skywatch/briefer/models/metar'
require_relative 'skywatch/briefer/models/taf_group'
require_relative 'skywatch/briefer/models/taf'
require_relative 'skywatch/briefer/models/pirep'
require_relative 'skywatch/briefer/models/winds_aloft'
require_relative 'skywatch/briefer/models/sigmet'
require_relative 'skywatch/briefer/models/airmet'
require_relative 'skywatch/briefer/models/tfr'
require_relative 'skywatch/briefer/models/afd'
require_relative 'skywatch/briefer/analysis/flight_category'
require_relative 'skywatch/briefer/analysis/crosswind_calculator'
require_relative 'skywatch/briefer/sources/metar'
require_relative 'skywatch/briefer/sources/taf'
require_relative 'skywatch/briefer/sources/pirep'
require_relative 'skywatch/briefer/sources/winds_aloft'
require_relative 'skywatch/briefer/sources/sigmet'
require_relative 'skywatch/briefer/sources/airmet'
require_relative 'skywatch/briefer/sources/afd'
require_relative 'skywatch/briefer/formatters/text'
require_relative 'skywatch/radar/models/state_vector'
require_relative 'skywatch/radar/sources/opensky'
require_relative 'skywatch/radar/analysis/proximity'
require_relative 'skywatch/radar/formatters/text'
require_relative 'skywatch/mayday/models/emergency'
require_relative 'skywatch/mayday/sources/emergency'
require_relative 'skywatch/mayday/formatters/text'
require_relative 'skywatch/nimbus/models/outlook'
require_relative 'skywatch/nimbus/sources/outlook'
require_relative 'skywatch/nimbus/models/storm_report'
require_relative 'skywatch/nimbus/models/convective_alert'
require_relative 'skywatch/nimbus/models/convection'
require_relative 'skywatch/nimbus/sources/storm_report'
require_relative 'skywatch/nimbus/sources/alerts'
require_relative 'skywatch/nimbus/formatters/text'
require_relative 'skywatch/brief/analysis/airport_locator'

module Skywatch
  class << self
    def client
      @client ||= Shared::Cache.new(client: Shared::Http.new)
    end

    def reset!
      @client = nil
    end

    def metar(*station_ids)
      Briefer::Sources::Metar.new.fetch(*station_ids)
    end

    def taf(*station_ids)
      Briefer::Sources::Taf.new.fetch(*station_ids)
    end

    def pireps(station_id, radius_nm: 100)
      Briefer::Sources::Pirep.new.fetch(station_id, radius_nm: radius_nm)
    end

    def winds_aloft(station_id, altitude_ft: nil)
      Briefer::Sources::WindsAloft.new.fetch(station_id, altitude_ft: altitude_ft)
    end

    def sigmets
      Briefer::Sources::Sigmet.new.fetch
    end

    def airmets
      Briefer::Sources::Airmet.new.fetch
    end

    def afd(wfo)
      Briefer::Sources::Afd.new.fetch(wfo)
    end

    def flights(lat:, lon:, radius_nm: 50)
      box = Radar::Analysis::Proximity.bbox(lat, lon, radius_nm: radius_nm)
      vectors = Radar::Sources::Opensky.new.states_bbox(**box)
      Radar::Analysis::Proximity.within_radius(vectors, lat: lat, lon: lon, radius_nm: radius_nm)
    end

    def track(callsign)
      Radar::Sources::Opensky.new.states_by_callsign(callsign)
    end

    def aircraft(icao24)
      Radar::Sources::Opensky.new.states_by_icao24(icao24)
    end

    def mayday(lat:, lon:, radius_nm: 100)
      Mayday::Sources::Emergency.new.near(lat: lat, lon: lon, radius_nm: radius_nm)
    end

    def outlook(day:, at: nil)
      outlooks = Nimbus::Sources::Outlook.new.fetch(day: day)
      return outlooks if at.nil?

      lat, lon = at
      covering = outlooks.select { |o| o.covers?(lat: lat, lon: lon) }
      covering.max_by(&:risk_score)
    end

    def storms(date: nil, type: nil, near: nil)
      reports = Nimbus::Sources::StormReport.new.fetch(date: date)
      reports = reports.select { |r| r.type == type } if type
      return reports if near.nil?

      lat = near.fetch(:lat)
      lon = near.fetch(:lon)
      radius_nm = near.fetch(:radius_nm)
      reports.select do |r|
        Radar::Analysis::Proximity.distance_nm(lat, lon, r.latitude, r.longitude) <= radius_nm
      end
    end

    def convection(at:, events: nil)
      alerts = if events
                 Nimbus::Sources::Alerts.new.fetch(at: at, events: events)
               else
                 Nimbus::Sources::Alerts.new.fetch(at: at)
               end

      Nimbus::Models::Convection.new(
        at: at,
        fetched_at: Time.now.utc,
        alerts: alerts
      )
    end

    def crosswind(station_id, runway_heading:)
      metars = metar(station_id)
      raise Error, "No METAR available for #{station_id}" if metars.empty?

      m = metars.first
      Briefer::Analysis::CrosswindCalculator.calculate(
        wind_direction_deg: m.wind_direction_deg || 0,
        wind_speed_kt: m.wind_speed_kt || 0,
        runway_heading: runway_heading
      )
    end
  end
end

require_relative 'skywatch/briefer/cli'
require_relative 'skywatch/radar/cli'
require_relative 'skywatch/mayday/cli'
require_relative 'skywatch/nimbus/cli'
require_relative 'skywatch/cli'
