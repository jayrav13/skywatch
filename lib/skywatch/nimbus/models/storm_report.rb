# frozen_string_literal: true

module Skywatch
  module Nimbus
    module Models
      class StormReport
        attr_reader :time, :type, :magnitude, :magnitude_raw,
                    :location, :county, :state,
                    :latitude, :longitude, :comments

        def initialize(time:, type:, magnitude:, magnitude_raw:,
                       location:, county:, state:,
                       latitude:, longitude:, comments:)
          @time = time
          @type = type
          @magnitude = magnitude
          @magnitude_raw = magnitude_raw
          @location = location
          @county = county
          @state = state
          @latitude = latitude
          @longitude = longitude
          @comments = comments
        end
      end
    end
  end
end
