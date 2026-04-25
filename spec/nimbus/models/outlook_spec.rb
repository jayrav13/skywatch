# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Models::Outlook do
  let(:attrs) do
    {
      day: 1,
      label: 'SLGT',
      valid_from: Time.utc(2026, 4, 19, 12),
      valid_to: Time.utc(2026, 4, 20, 12),
      issued_at: Time.utc(2026, 4, 19, 12),
      forecaster: 'GUYER',
      geometry: nil
    }
  end

  describe '#initialize' do
    it 'stores day, label, times, forecaster, geometry' do
      outlook = described_class.new(**attrs)
      expect(outlook.day).to eq(1)
      expect(outlook.label).to eq('SLGT')
      expect(outlook.valid_from).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_to).to eq(Time.utc(2026, 4, 20, 12))
      expect(outlook.issued_at).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.forecaster).to eq('GUYER')
    end
  end

  describe 'risk classification' do
    {
      'TSTM' => [:general_thunder, 1, 'General Thunderstorms'],
      'MRGL' => [:marginal,        2, 'Marginal Risk'],
      'SLGT' => [:slight,          3, 'Slight Risk'],
      'ENH' => [:enhanced,        4, 'Enhanced Risk'],
      'MDT' => [:moderate,        5, 'Moderate Risk'],
      'HIGH' => [:high,            6, 'High Risk']
    }.each do |label, (level, score, description)|
      it "maps #{label} → #{level} / #{score} / #{description.inspect}" do
        outlook = described_class.new(**attrs, label: label)
        expect(outlook.risk_level).to eq(level)
        expect(outlook.risk_score).to eq(score)
        expect(outlook.description).to eq(description)
      end
    end

    it 'raises KeyError for an unknown LABEL' do
      outlook = described_class.new(**attrs, label: 'XYZ')
      expect { outlook.risk_level }.to raise_error(KeyError)
    end
  end

  describe '.from_spc_feature' do
    let(:feature) do
      JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))
          .fetch('features').first
    end

    it 'builds an Outlook with day + parsed properties' do
      outlook = described_class.from_spc_feature(feature, day: 1)
      expect(outlook.day).to eq(1)
      expect(outlook.label).to eq('MRGL')
      expect(outlook.issued_at).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_from).to eq(Time.utc(2026, 4, 19, 12))
      expect(outlook.valid_to).to eq(Time.utc(2026, 4, 20, 12))
      expect(outlook.forecaster).to eq('GUYER')
    end

    it 'decodes geometry as an RGeo MultiPolygon' do
      outlook = described_class.from_spc_feature(feature, day: 1)
      expect(outlook.geometry).to be_a(RGeo::Feature::MultiPolygon)
    end

    it 'raises ParseError when geometry is missing' do
      broken = feature.merge('geometry' => nil)
      expect { described_class.from_spc_feature(broken, day: 1) }
        .to raise_error(Skywatch::ParseError)
    end
  end

  describe '#covers?' do
    let(:features) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'] }
    let(:mrgl) { described_class.from_spc_feature(features[0], day: 1) }
    let(:slgt) { described_class.from_spc_feature(features[1], day: 1) }

    it 'is true for a point inside the polygon' do
      expect(mrgl.covers?(lat: 40.7, lon: -74.0)).to be(true)
    end

    it 'is false for a point outside the polygon' do
      expect(mrgl.covers?(lat: 30.0, lon: -40.0)).to be(false)
    end

    it 'distinguishes an inner polygon from an outer one' do
      expect(mrgl.covers?(lat: 41.4, lon: -74.9)).to be(true)
      expect(slgt.covers?(lat: 41.4, lon: -74.9)).to be(false)
    end
  end

  describe '#to_h' do
    let(:feature) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'].first }
    let(:outlook) { described_class.from_spc_feature(feature, day: 1) }

    it 'includes classification + timing + forecaster + GeoJSON geometry' do
      hash = outlook.to_h
      expect(hash[:day]).to eq(1)
      expect(hash[:label]).to eq('MRGL')
      expect(hash[:risk_level]).to eq(:marginal)
      expect(hash[:risk_score]).to eq(2)
      expect(hash[:description]).to eq('Marginal Risk')
      expect(hash[:valid_from]).to eq('2026-04-19T12:00:00Z')
      expect(hash[:valid_to]).to eq('2026-04-20T12:00:00Z')
      expect(hash[:issued_at]).to eq('2026-04-19T12:00:00Z')
      expect(hash[:forecaster]).to eq('GUYER')
      expect(hash[:geometry]).to be_a(Hash)
      expect(hash[:geometry]['type']).to eq('MultiPolygon')
    end
  end

  describe '#to_json' do
    let(:feature) { JSON.parse(File.read('spec/fixtures/spc/day1_synthetic.geojson'))['features'].first }
    let(:outlook) { described_class.from_spc_feature(feature, day: 1) }

    it 'is the JSON encoding of #to_h' do
      expect(JSON.parse(outlook.to_json)).to eq(JSON.parse(outlook.to_h.to_json))
    end
  end
end
