# frozen_string_literal: true

RSpec.describe Skywatch::Shared::Geometry do
  describe ".polygon_from_coords" do
    it "builds an RGeo polygon from Position array" do
      coords = [
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -73.0),
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0)
      ]
      polygon = described_class.polygon_from_coords(coords)
      expect(polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end

    it "returns nil for fewer than 3 points" do
      coords = [
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0)
      ]
      expect(described_class.polygon_from_coords(coords)).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.polygon_from_coords(nil)).to be_nil
    end
  end

  describe ".point" do
    it "builds an RGeo point from lat/lon" do
      point = described_class.point(40.87, -74.28)
      expect(point).to be_a(RGeo::Geographic::SphericalPointImpl)
      expect(point.latitude).to be_within(0.001).of(40.87)
    end
  end

  describe "FACTORY" do
    it "is a spherical factory with SRID 4326" do
      expect(described_class::FACTORY.srid).to eq(4326)
    end
  end
end
