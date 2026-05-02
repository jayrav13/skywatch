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
                    :current_conditions, :destination_forecast, :winds_aloft, :afd, :note

        # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
        def initialize(airport:, coordinates:, wfo:, fetched_at:,
                       adverse_conditions:, vfr_not_recommended:,
                       current_conditions:, destination_forecast:, winds_aloft:, afd:,
                       note: nil)
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
          @note = note
        end
        # rubocop:enable Metrics/ParameterLists, Metrics/MethodLength

        # rubocop:disable Metrics/MethodLength
        def to_h
          base = {
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
          note ? base.merge(note: note) : base
        end
        # rubocop:enable Metrics/MethodLength

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
