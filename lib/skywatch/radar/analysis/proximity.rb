# frozen_string_literal: true

module Skywatch
  module Radar
    module Analysis
      module Proximity
        NM_PER_DEG_LAT = 60.0

        def self.bbox(lat, lon, radius_nm: 50)
          lat_offset = radius_nm / NM_PER_DEG_LAT
          lon_offset = radius_nm / (NM_PER_DEG_LAT * Math.cos(lat * Math::PI / 180))

          {
            lamin: (lat - lat_offset).round(4),
            lamax: (lat + lat_offset).round(4),
            lomin: (lon - lon_offset).round(4),
            lomax: (lon + lon_offset).round(4)
          }
        end

        def self.distance_nm(lat1, lon1, lat2, lon2) # rubocop:disable Metrics/AbcSize
          return 0 if lat1 == lat2 && lon1 == lon2

          rlat1 = lat1 * Math::PI / 180
          rlat2 = lat2 * Math::PI / 180
          dlat = (lat2 - lat1) * Math::PI / 180
          dlon = (lon2 - lon1) * Math::PI / 180

          a = (Math.sin(dlat / 2)**2) + (Math.cos(rlat1) * Math.cos(rlat2) * (Math.sin(dlon / 2)**2))
          c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

          (3440.065 * c).round(1)
        end

        def self.within_radius(state_vectors, lat:, lon:, radius_nm:)
          state_vectors.select do |sv|
            next false if sv.latitude.nil? || sv.longitude.nil?

            distance_nm(lat, lon, sv.latitude, sv.longitude) <= radius_nm
          end
        end
      end
    end
  end
end
