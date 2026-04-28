# frozen_string_literal: true

require 'time'
require 'json'

module Skywatch
  module Brief
    module Models
      class Brief
        AIM_SECTION = '7-1-5'

        SYNOPSIS_UNAVAILABLE = {
          available: false,
          reason: 'no synopsis source in skywatch — see afd slot'
        }.freeze

        ENROUTE_UNAVAILABLE = {
          available: false,
          reason: 'single-point brief; route input deferred from MVP'
        }.freeze

        NOTAMS_UNAVAILABLE = {
          available: false,
          reason: 'NOTAMs not in skywatch yet — Sectional domain not yet built'
        }.freeze

        ATC_DELAYS_UNAVAILABLE = {
          available: false,
          reason: 'ATC delays not in skywatch yet — no source'
        }.freeze

        attr_reader :airport, :coordinates, :wfo, :fetched_at,
                    :adverse_conditions, :vfr_not_recommended,
                    :current_conditions, :destination_forecast, :winds_aloft, :afd

        # rubocop:disable Metrics/ParameterLists
        def initialize(airport:, coordinates:, wfo:, fetched_at:,
                       adverse_conditions:, vfr_not_recommended:,
                       current_conditions:, destination_forecast:, winds_aloft:, afd:)
          @airport = airport
          @coordinates = coordinates
          @wfo = wfo
          @fetched_at = fetched_at
          @adverse_conditions = adverse_conditions
          @vfr_not_recommended = vfr_not_recommended
          @current_conditions = current_conditions
          @destination_forecast = destination_forecast
          @winds_aloft = winds_aloft
          @afd = afd
        end
        # rubocop:enable Metrics/ParameterLists

        # rubocop:disable Metrics/MethodLength
        def to_h
          {
            airport: airport,
            coordinates: coordinates,
            wfo: wfo,
            fetched_at: fetched_at&.iso8601,
            aim_section: AIM_SECTION,
            adverse_conditions: adverse_conditions,
            vfr_not_recommended: vfr_not_recommended,
            synopsis: SYNOPSIS_UNAVAILABLE,
            current_conditions: current_conditions,
            enroute_forecast: ENROUTE_UNAVAILABLE,
            destination_forecast: destination_forecast,
            winds_aloft: winds_aloft,
            notams: NOTAMS_UNAVAILABLE,
            atc_delays: ATC_DELAYS_UNAVAILABLE,
            afd: afd
          }
        end
        # rubocop:enable Metrics/MethodLength

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
