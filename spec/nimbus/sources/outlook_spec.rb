# frozen_string_literal: true

RSpec.describe Skywatch::Nimbus::Sources::Outlook do
  subject(:source) { described_class.new }

  describe '#fetch' do
    let(:fixture) { File.read('spec/fixtures/spc/day1_synthetic.geojson') }

    before do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
        .to_return(status: 200, body: fixture,
                   headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns an Outlook per feature' do
      result = source.fetch(day: 1)
      expect(result).to all(be_a(Skywatch::Nimbus::Models::Outlook))
      expect(result.map(&:label)).to eq(%w[MRGL SLGT])
    end

    it 'stamps each Outlook with the requested day' do
      result = source.fetch(day: 1)
      expect(result.map(&:day)).to all(eq(1))
    end

    it 'raises ArgumentError for day 0, 4, 99, or nil' do
      [0, 4, 99, nil].each do |bad|
        expect { source.fetch(day: bad) }.to raise_error(ArgumentError, /day must be 1, 2, or 3/)
      end
    end

    it 'returns [] when the FeatureCollection is empty' do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day1otlk_cat.lyr.geojson')
        .to_return(status: 200,
                   body: File.read('spec/fixtures/spc/day1_empty.geojson'),
                   headers: { 'Content-Type' => 'application/geo+json' })

      expect(source.fetch(day: 1)).to eq([])
    end

    it 'builds the day-2 URL correctly' do
      stub_request(:get, 'https://www.spc.noaa.gov/products/outlook/day2otlk_cat.lyr.geojson')
        .to_return(status: 200, body: fixture,
                   headers: { 'Content-Type' => 'application/geo+json' })

      expect(source.fetch(day: 2).map(&:day)).to all(eq(2))
    end
  end
end
