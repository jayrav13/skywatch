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
  end
end
