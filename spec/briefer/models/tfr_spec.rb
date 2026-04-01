# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Models::Tfr do
  let(:geojson) { JSON.parse(File.read('spec/fixtures/tfrs/feature_collection.json')) }
  let(:feature) { geojson['features'].first }

  describe '.from_geojson_feature' do
    subject(:tfr) { described_class.from_geojson_feature(feature) }

    it 'parses properties' do
      expect(tfr.notam_key).to eq('6/3475-1-FDC-F')
      expect(tfr.title).to include('Beale AFB')
      expect(tfr.state).to eq('CA')
      expect(tfr.type).to eq('SECURITY')
      expect(tfr.center_id).to eq('ZOA')
    end

    it 'parses last_modified' do
      expect(tfr.last_modified).to be_a(Time)
      expect(tfr.last_modified.year).to eq(2026)
      expect(tfr.last_modified.month).to eq(3)
    end

    it 'parses GeoJSON coords (lon,lat) into Position (lat,lon)' do
      expect(tfr.coords).to all(be_a(Skywatch::Shared::Position))
      expect(tfr.coords.first.lat).to be_within(0.01).of(39.13)
      expect(tfr.coords.first.lon).to be_within(0.01).of(-121.65)
    end
  end

  describe '#polygon' do
    subject(:tfr) { described_class.from_geojson_feature(feature) }

    it 'returns an RGeo polygon' do
      expect(tfr.polygon).to be_a(RGeo::Geographic::SphericalPolygonImpl)
    end
  end

  describe '#to_h' do
    subject(:tfr) { described_class.from_geojson_feature(feature) }

    it 'returns a hash with key fields' do
      hash = tfr.to_h
      expect(hash[:notam_key]).to eq('6/3475-1-FDC-F')
      expect(hash[:state]).to eq('CA')
      expect(hash[:type]).to eq('SECURITY')
    end
  end
end
