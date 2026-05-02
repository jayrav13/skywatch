# frozen_string_literal: true

module Skywatch
  module Brief
    module Analysis
      module AdverseFilter
        def self.covers?(product, lat, lon)
          polygon = product.polygon
          return false if polygon.nil?

          polygon.contains?(Skywatch::Shared::Geometry.point(lat, lon))
        rescue RGeo::Error::InvalidGeometry
          false
        end

        def self.within(items, lat:, lon:, radius_nm:)
          items.select do |item|
            next false if item.latitude.nil? || item.longitude.nil?

            Skywatch::Radar::Analysis::Proximity.distance_nm(lat, lon, item.latitude, item.longitude) <= radius_nm
          end
        end

        def self.partition_pireps(pireps)
          urgent, informational = pireps.partition do |p|
            p.pirep_type.to_s.include?('urgent')
          end
          { urgent: urgent, informational: informational }
        end
      end
    end
  end
end
