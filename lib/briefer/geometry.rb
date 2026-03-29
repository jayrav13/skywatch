# frozen_string_literal: true

require "rgeo"

module Briefer
  module Geometry
    FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

    def self.polygon_from_coords(coords)
      return nil if coords.nil? || coords.size < 3

      points = coords.map { |c| FACTORY.point(c.lon, c.lat) }
      ring = FACTORY.linear_ring(points)
      FACTORY.polygon(ring)
    end

    def self.point(lat, lon)
      FACTORY.point(lon, lat)
    end
  end
end
