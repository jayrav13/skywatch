# frozen_string_literal: true

RSpec.describe Skywatch do
  describe '.outlook' do
    let(:fixture) { File.read('spec/fixtures/spc/day1_synthetic.geojson') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
        .to_return(status: 200, body: fixture,
                   headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns every outlook for the given day when no :at is provided' do
      result = described_class.outlook(day: 1)
      expect(result.map(&:label)).to eq(%w[MRGL SLGT])
    end

    it 'returns the highest-risk covering outlook when :at is inside both regions' do
      result = described_class.outlook(day: 1, at: [40.7, -74.0])
      expect(result).to be_a(Skywatch::Nimbus::Models::Outlook)
      expect(result.label).to eq('SLGT')
    end

    it 'returns the only covering outlook when :at is inside just one region' do
      result = described_class.outlook(day: 1, at: [41.4, -74.9])
      expect(result.label).to eq('MRGL')
    end

    it 'returns nil when :at is covered by no features' do
      result = described_class.outlook(day: 1, at: [30.0, -40.0])
      expect(result).to be_nil
    end
  end
end
