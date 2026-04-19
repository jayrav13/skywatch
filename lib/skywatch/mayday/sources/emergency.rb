# frozen_string_literal: true

module Skywatch
  module Mayday
    module Sources
      class Emergency
        DEFAULT_RADIUS_NM = 100

        def initialize(opensky: Skywatch::Radar::Sources::Opensky.new)
          @opensky = opensky
        end

        def near(lat:, lon:, radius_nm: DEFAULT_RADIUS_NM)
          bbox = Skywatch::Radar::Analysis::Proximity.bbox(lat, lon, radius_nm: radius_nm)
          vectors = @opensky.states_bbox(**bbox)
          in_radius = Skywatch::Radar::Analysis::Proximity.within_radius(
            vectors, lat: lat, lon: lon, radius_nm: radius_nm
          )
          in_radius.select(&:emergency?).map { |sv| Models::Emergency.new(sv) }
        end
      end
    end
  end
end
