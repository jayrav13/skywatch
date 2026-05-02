# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::AdverseFilter do
  describe '.covers?' do
    let(:square_around_kcdw) do
      coords = [
        Skywatch::Shared::Position.new(lat: 41.0, lon: -75.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
        Skywatch::Shared::Position.new(lat: 40.0, lon: -75.0),
        Skywatch::Shared::Position.new(lat: 41.0, lon: -75.0)
      ]
      Skywatch::Briefer::Models::Sigmet.new(coords: coords)
    end

    it 'returns true when the airport is inside the polygon' do
      expect(described_class.covers?(square_around_kcdw, 40.875, -74.282)).to be true
    end

    it 'returns false when the airport is outside the polygon' do
      expect(described_class.covers?(square_around_kcdw, 35.0, -100.0)).to be false
    end

    it 'returns false when the product has no polygon' do
      degenerate = Skywatch::Briefer::Models::Sigmet.new(coords: [])
      expect(described_class.covers?(degenerate, 40.875, -74.282)).to be false
    end

    it 'returns false when the polygon is self-intersecting (RGeo InvalidGeometry)' do
      # Bowtie ring: edges cross — RGeo raises Self-intersection on contains?
      bowtie = Skywatch::Briefer::Models::Sigmet.new(coords: [
                                                       Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0),
                                                       Skywatch::Shared::Position.new(lat: 41.0, lon: -73.0),
                                                       Skywatch::Shared::Position.new(lat: 40.0, lon: -73.0),
                                                       Skywatch::Shared::Position.new(lat: 41.0, lon: -74.0),
                                                       Skywatch::Shared::Position.new(lat: 40.0, lon: -74.0)
                                                     ])
      expect { described_class.covers?(bowtie, 40.5, -73.5) }.not_to raise_error
      expect(described_class.covers?(bowtie, 40.5, -73.5)).to be false
    end
  end

  describe '.within' do
    let(:near_pirep) do
      Skywatch::Briefer::Models::Pirep.new(latitude: 40.9, longitude: -74.3)
    end
    let(:far_pirep) do
      Skywatch::Briefer::Models::Pirep.new(latitude: 30.0, longitude: -90.0)
    end

    it 'keeps items within radius' do
      result = described_class.within([near_pirep, far_pirep], lat: 40.875, lon: -74.282, radius_nm: 100)
      expect(result).to eq([near_pirep])
    end

    it 'returns empty when nothing is in range' do
      expect(described_class.within([far_pirep], lat: 40.875, lon: -74.282, radius_nm: 100)).to eq([])
    end

    it 'skips items missing latitude or longitude' do
      headless = Skywatch::Briefer::Models::Pirep.new(latitude: nil, longitude: nil)
      expect(described_class.within([headless], lat: 40.0, lon: -74.0, radius_nm: 100)).to eq([])
    end
  end

  describe '.partition_pireps' do
    let(:routine) { Skywatch::Briefer::Models::Pirep.new(pirep_type: :pirep) }
    let(:urgent) { Skywatch::Briefer::Models::Pirep.new(pirep_type: :'urgent pirep') }

    it 'splits urgent (any pirep_type containing "urgent") from informational' do
      result = described_class.partition_pireps([routine, urgent])
      expect(result[:urgent]).to eq([urgent])
      expect(result[:informational]).to eq([routine])
    end

    it 'treats nil pirep_type as informational' do
      blank = Skywatch::Briefer::Models::Pirep.new(pirep_type: nil)
      result = described_class.partition_pireps([blank])
      expect(result[:urgent]).to eq([])
      expect(result[:informational]).to eq([blank])
    end
  end
end
