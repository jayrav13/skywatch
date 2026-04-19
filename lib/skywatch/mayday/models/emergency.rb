# frozen_string_literal: true

require 'forwardable'
require 'json'

module Skywatch
  module Mayday
    module Models
      class Emergency
        extend Forwardable

        TYPES = {
          '7500' => { type: :hijack,        label: 'HIJACK' },
          '7600' => { type: :radio_failure, label: 'RADIO FAILURE' },
          '7700' => { type: :general,       label: 'GENERAL EMERGENCY' }
        }.freeze

        attr_reader :state_vector

        def_delegators :@state_vector,
                       :callsign, :icao24, :latitude, :longitude,
                       :altitude_ft, :velocity_kt, :on_ground, :squawk

        def initialize(state_vector)
          unless TYPES.key?(state_vector.squawk)
            raise ArgumentError, "Not an emergency squawk: #{state_vector.squawk.inspect}"
          end

          @state_vector = state_vector
        end

        def emergency_type
          TYPES.fetch(squawk)[:type]
        end

        def label
          TYPES.fetch(squawk)[:label]
        end

        def heading_deg
          state_vector.true_track_deg
        end

        def to_h
          {
            callsign: callsign, icao24: icao24, squawk: squawk,
            emergency_type: emergency_type, label: label,
            latitude: latitude, longitude: longitude,
            altitude_ft: altitude_ft, velocity_kt: velocity_kt, heading_deg: heading_deg,
            on_ground: on_ground
          }
        end

        def to_json(*)
          to_h.to_json(*)
        end
      end
    end
  end
end
