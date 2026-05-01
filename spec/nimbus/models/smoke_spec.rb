# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rgeo/geo_json'

RSpec.describe Skywatch::Nimbus::Models::Smoke do
  let(:feature) do
    JSON.parse(File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json'))
        .fetch('features').first
  end

  describe '.from_arcgis_feature' do
    it 'parses density / satellite / Start / End_ / geometry' do
      smoke = described_class.from_arcgis_feature(feature)

      expect(smoke.density_raw).to eq('Heavy')
      expect(smoke.satellite).to eq('GOES-EAST')
      expect(smoke.start_time).to eq(Time.utc(2026, 4, 30, 12, 0))
      expect(smoke.end_time).to eq(Time.utc(2026, 4, 30, 18, 0))
      expect(smoke.geometry).to be_a(RGeo::Feature::Polygon)
    end

    it 'tolerates missing attributes block' do
      smoke = described_class.from_arcgis_feature({ 'geometry' => nil })
      expect(smoke.density_raw).to be_nil
      expect(smoke.satellite).to be_nil
      expect(smoke.geometry).to be_nil
    end

    it 'tolerates missing geometry' do
      f = feature.dup
      f['geometry'] = nil
      smoke = described_class.from_arcgis_feature(f)
      expect(smoke.geometry).to be_nil
    end

    it 'tolerates empty rings' do
      f = feature.dup
      f['geometry'] = { 'rings' => [] }
      smoke = described_class.from_arcgis_feature(f)
      expect(smoke.geometry).to be_nil
    end
  end

  describe 'julian time parser' do
    it 'parses "2026120 1200" as April 30 2026 12:00 UTC' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Start' => '2026120 1200', 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.start_time).to eq(Time.utc(2026, 4, 30, 12, 0))
    end

    it 'parses "2026001 0000" as January 1 2026 00:00 UTC' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Start' => '2026001 0000', 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.start_time).to eq(Time.utc(2026, 1, 1, 0, 0))
    end

    it 'returns nil for nil or empty Start' do
      [nil, ''].each do |val|
        smoke = described_class.from_arcgis_feature(
          { 'attributes' => { 'Start' => val, 'Density' => 'Light' }, 'geometry' => nil }
        )
        expect(smoke.start_time).to be_nil
      end
    end
  end

  describe 'density accessors' do
    %w[Light Medium Heavy].each_with_index do |density, idx|
      it "exposes level / score / description for #{density}" do
        smoke = described_class.from_arcgis_feature(
          { 'attributes' => { 'Density' => density }, 'geometry' => nil }
        )
        expect(smoke.density_level).to eq(density.downcase.to_sym)
        expect(smoke.density_score).to eq(idx + 1)
        expect(smoke.description).to eq("#{density} smoke")
      end
    end

    it 'raises KeyError when density is unknown' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Density' => 'Apocalyptic' }, 'geometry' => nil }
      )
      expect { smoke.density_level }.to raise_error(KeyError)
      expect { smoke.density_score }.to raise_error(KeyError)
      expect { smoke.description }.to raise_error(KeyError)
    end
  end

  describe '#to_h' do
    it 'serializes density quartet, satellite, times, and geometry as GeoJSON' do
      smoke = described_class.from_arcgis_feature(feature)
      hash = smoke.to_h

      expect(hash).to include(
        density: :heavy,
        density_raw: 'Heavy',
        density_score: 3,
        description: 'Heavy smoke',
        satellite: 'GOES-EAST',
        start_time: '2026-04-30T12:00:00Z',
        end_time: '2026-04-30T18:00:00Z'
      )
      expect(hash[:geometry]).to be_a(Hash)
      expect(hash[:geometry]['type']).to eq('Polygon')
    end

    it 'returns nil geometry when geometry is nil' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.to_h[:geometry]).to be_nil
    end

    it 'returns nil times when source times are nil' do
      smoke = described_class.from_arcgis_feature(
        { 'attributes' => { 'Density' => 'Light' }, 'geometry' => nil }
      )
      expect(smoke.to_h[:start_time]).to be_nil
      expect(smoke.to_h[:end_time]).to be_nil
    end
  end

  describe '#to_json' do
    it 'round-trips through JSON' do
      smoke = described_class.from_arcgis_feature(feature)
      parsed = JSON.parse(smoke.to_json)
      expect(parsed['density_raw']).to eq('Heavy')
      expect(parsed['satellite']).to eq('GOES-EAST')
    end
  end
end
