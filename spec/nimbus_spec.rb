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

  describe '.storms' do
    let(:csv) { File.read('spec/fixtures/spc/sample.csv') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/today.csv')
        .to_return(status: 200, body: csv,
                   headers: { 'Content-Type' => 'text/csv' })
    end

    it 'returns all reports when called with no filters' do
      result = described_class.storms
      expect(result.length).to eq(5)
    end

    it 'filters by type when :type is given' do
      result = described_class.storms(type: :wind)
      expect(result.map(&:type).uniq).to eq([:wind])
      expect(result.length).to eq(2)
    end

    it 'filters by proximity when :near is given' do
      result = described_class.storms(near: { lat: 40.7, lon: -74.0, radius_nm: 100 })
      expect(result.length).to eq(3)
      expect(result.map(&:type)).to contain_exactly(:tornado, :wind, :hail)
    end

    it 'combines :type and :near' do
      result = described_class.storms(type: :wind, near: { lat: 40.7, lon: -74.0, radius_nm: 100 })
      expect(result.length).to eq(1)
      expect(result.first.location).to eq('JERSEY CITY')
    end

    it 'raises KeyError when :near is missing a required key' do
      expect {
        described_class.storms(near: { lat: 40.7, lon: -74.0 })
      }.to raise_error(KeyError)
    end

    it 'fetches YYMMDD.csv when :date is given' do
      stub_request(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
        .to_return(status: 200, body: csv,
                   headers: { 'Content-Type' => 'text/csv' })

      described_class.storms(date: Date.new(2026, 4, 15))
      expect(WebMock).to have_requested(:get, 'https://www.spc.noaa.gov/climo/reports/260415.csv')
    end
  end
end
