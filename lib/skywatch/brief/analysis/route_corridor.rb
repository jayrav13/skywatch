# frozen_string_literal: true

module Skywatch
  module Brief
    module Analysis
      module RouteCorridor
        EARTH_RADIUS_NM = 3440.065

        # Returns array of [lat, lon] pairs (in degrees) along the great-circle path,
        # sampled at most spacing_nm apart, including both endpoints.
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def self.waypoints(from_lat:, from_lon:, to_lat:, to_lon:, spacing_nm: 25)
          lat1 = from_lat * Math::PI / 180
          lon1 = from_lon * Math::PI / 180
          lat2 = to_lat * Math::PI / 180
          lon2 = to_lon * Math::PI / 180

          d_rad = haversine_distance_rad(lat1, lon1, lat2, lon2)
          total_nm = d_rad * EARTH_RADIUS_NM

          n = [1, (total_nm / spacing_nm).ceil].max

          (0..n).map do |i|
            fraction = i.to_f / n
            rlat, rlon = interpolate(lat1, lon1, lat2, lon2, fraction, d_rad)
            [(rlat * 180 / Math::PI).round(6), (rlon * 180 / Math::PI).round(6)]
          end
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        # Initial bearing (degrees, 0-360) from (from_lat, from_lon) to (to_lat, to_lon).
        # rubocop:disable Metrics/AbcSize
        def self.bearing_deg(from_lat:, from_lon:, to_lat:, to_lon:)
          lat1 = from_lat * Math::PI / 180
          lon1 = from_lon * Math::PI / 180
          lat2 = to_lat * Math::PI / 180
          lon2 = to_lon * Math::PI / 180

          dlon = lon2 - lon1
          y = Math.sin(dlon) * Math.cos(lat2)
          x = (Math.cos(lat1) * Math.sin(lat2)) - (Math.sin(lat1) * Math.cos(lat2) * Math.cos(dlon))
          theta = Math.atan2(y, x) * 180 / Math::PI
          (theta + 360) % 360
        end
        # rubocop:enable Metrics/AbcSize

        # Total great-circle distance in nautical miles.
        def self.distance_nm(from_lat:, from_lon:, to_lat:, to_lon:)
          lat1 = from_lat * Math::PI / 180
          lon1 = from_lon * Math::PI / 180
          lat2 = to_lat * Math::PI / 180
          lon2 = to_lon * Math::PI / 180
          d_rad = haversine_distance_rad(lat1, lon1, lat2, lon2)
          (d_rad * EARTH_RADIUS_NM).round(1)
        end

        # Spherical linear interpolation between two points given as radians.
        # d is the pre-computed angular distance (radians).
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/ParameterLists
        def self.interpolate(lat1, lon1, lat2, lon2, fraction, angular_dist = nil)
          angular_dist ||= haversine_distance_rad(lat1, lon1, lat2, lon2)
          return [lat1, lon1] if angular_dist.zero? || fraction.zero?
          return [lat2, lon2] if (fraction - 1.0).abs < Float::EPSILON

          a = Math.sin((1 - fraction) * angular_dist) / Math.sin(angular_dist)
          b = Math.sin(fraction * angular_dist) / Math.sin(angular_dist)
          x = (a * Math.cos(lat1) * Math.cos(lon1)) + (b * Math.cos(lat2) * Math.cos(lon2))
          y = (a * Math.cos(lat1) * Math.sin(lon1)) + (b * Math.cos(lat2) * Math.sin(lon2))
          z = (a * Math.sin(lat1)) + (b * Math.sin(lat2))
          rlat = Math.atan2(z, Math.sqrt((x * x) + (y * y)))
          rlon = Math.atan2(y, x)
          [rlat, rlon]
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/ParameterLists

        # Haversine angular distance in radians between two points given in radians.
        # rubocop:disable Metrics/AbcSize
        def self.haversine_distance_rad(lat1, lon1, lat2, lon2)
          dlat = lat2 - lat1
          dlon = lon2 - lon1
          a = (Math.sin(dlat / 2)**2) + (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(dlon / 2)**2))
          2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        end
        # rubocop:enable Metrics/AbcSize

        private_class_method :interpolate, :haversine_distance_rad
      end
    end
  end
end
