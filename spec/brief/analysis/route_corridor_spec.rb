# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::RouteCorridor do
  # KCDW: 40.875, -74.282
  # KACY: 39.457, -74.577  (~100 nm south)
  # KJFK: 40.641, -73.778  (~30 nm east of KCDW)

  describe '.waypoints' do
    it 'always includes the start and end points' do
      pts = described_class.waypoints(from_lat: 40.875, from_lon: -74.282,
                                      to_lat: 39.457, to_lon: -74.577)
      expect(pts.first).to eq([40.875, -74.282])
      expect(pts.last).to eq([39.457, -74.577])
    end

    it 'returns at least 2 waypoints even for a very short route' do
      pts = described_class.waypoints(from_lat: 40.875, from_lon: -74.282,
                                      to_lat: 40.876, to_lon: -74.282)
      expect(pts.size).to be >= 2
    end

    it 'produces waypoints spaced at most spacing_nm apart' do
      pts = described_class.waypoints(from_lat: 40.875, from_lon: -74.282,
                                      to_lat: 39.457, to_lon: -74.577,
                                      spacing_nm: 25)
      pts.each_cons(2) do |a, b|
        dist = Skywatch::Radar::Analysis::Proximity.distance_nm(a[0], a[1], b[0], b[1])
        expect(dist).to be <= 26 # slight float tolerance
      end
    end

    it 'returns correct count for ~86 nm route with 25 nm spacing' do
      # KCDW to KACY is about 86 nm → ceil(86/25) = 4 segments → 5 waypoints
      pts = described_class.waypoints(from_lat: 40.875, from_lon: -74.282,
                                      to_lat: 39.457, to_lon: -74.577,
                                      spacing_nm: 25)
      # 4 segments + 1 = 5 waypoints (allow slight floating point variation)
      expect(pts.size).to be_between(4, 6)
    end

    it 'returns 2 waypoints (start + end) for a route shorter than spacing' do
      # A 10-nm route with 25-nm spacing should give ceil(10/25) = 1 segment → 2 pts
      # 10 nm ≈ 0.167 degrees of latitude north-south
      pts = described_class.waypoints(from_lat: 40.000, from_lon: -74.000,
                                      to_lat: 40.167, to_lon: -74.000,
                                      spacing_nm: 25)
      expect(pts.size).to eq(2)
    end

    it 'intermediate points lie between origin and destination' do
      pts = described_class.waypoints(from_lat: 40.875, from_lon: -74.282,
                                      to_lat: 39.457, to_lon: -74.577,
                                      spacing_nm: 25)
      # All latitudes should be between from and to (roughly south-trending route)
      min_lat = [40.875, 39.457].min
      max_lat = [40.875, 39.457].max
      lats = pts.map(&:first)
      lats.each do |lat|
        expect(lat).to be_between(min_lat - 0.01, max_lat + 0.01)
      end
    end
  end

  describe '.bearing_deg' do
    it 'returns ~90 for due-east route' do
      # Moving east: same latitude, increasing longitude
      bearing = described_class.bearing_deg(from_lat: 40.0, from_lon: -74.0,
                                            to_lat: 40.0, to_lon: -73.0)
      expect(bearing).to be_within(2).of(90)
    end

    it 'returns ~270 for due-west route' do
      bearing = described_class.bearing_deg(from_lat: 40.0, from_lon: -74.0,
                                            to_lat: 40.0, to_lon: -75.0)
      expect(bearing).to be_within(2).of(270)
    end

    it 'returns ~0 (or 360) for due-north route' do
      bearing = described_class.bearing_deg(from_lat: 39.0, from_lon: -74.0,
                                            to_lat: 40.0, to_lon: -74.0)
      # bearing should be near 0/360
      expect([bearing, (bearing - 360).abs].min).to be_within(2).of(0)
    end

    it 'returns ~180 for due-south route' do
      bearing = described_class.bearing_deg(from_lat: 40.0, from_lon: -74.0,
                                            to_lat: 39.0, to_lon: -74.0)
      expect(bearing).to be_within(2).of(180)
    end

    it 'returns value in [0, 360) range' do
      bearing = described_class.bearing_deg(from_lat: 40.875, from_lon: -74.282,
                                            to_lat: 39.457, to_lon: -74.577)
      expect(bearing).to be >= 0
      expect(bearing).to be < 360
    end

    it 'returns southerly bearing for KCDW to KACY' do
      # KACY is south-southwest of KCDW
      bearing = described_class.bearing_deg(from_lat: 40.875, from_lon: -74.282,
                                            to_lat: 39.457, to_lon: -74.577)
      expect(bearing).to be_between(170, 210)
    end
  end

  describe '.distance_nm' do
    it 'returns 0 for same point' do
      expect(described_class.distance_nm(from_lat: 40.0, from_lon: -74.0,
                                         to_lat: 40.0, to_lon: -74.0)).to eq(0.0)
    end

    it 'returns approximately the right distance between KCDW and KACY (~86 nm)' do
      dist = described_class.distance_nm(from_lat: 40.875, from_lon: -74.282,
                                         to_lat: 39.457, to_lon: -74.577)
      expect(dist).to be_within(5).of(86)
    end
  end
end
