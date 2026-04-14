# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Sigmet do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:active_sigmets) { JSON.parse(File.read('spec/fixtures/sigmets/active.json')) }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
      .with(query: { format: 'json' })
      .to_return(status: 200, body: active_sigmets.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch' do
    it 'returns an array of Sigmet models' do
      sigmets = source.fetch
      expect(sigmets).to all(be_a(Skywatch::Briefer::Models::Sigmet))
    end

    it 'returns all active SIGMETs' do
      sigmets = source.fetch
      expect(sigmets.size).to eq(2)
    end

    it 'maps fields correctly' do
      sigmet = source.fetch.first
      expect(sigmet.series_id).to eq('3E')
      expect(sigmet.issuing_center).to eq('KKCI')
      expect(sigmet.hazard).to eq('CONVECTIVE')
      expect(sigmet.altitude_hi_ft).to eq(32_000)
    end

    it 'parses coords into Position objects' do
      sigmet = source.fetch.first
      expect(sigmet.coords).not_to be_empty
      expect(sigmet.coords.first).to be_a(Skywatch::Shared::Position)
    end

    it 'returns empty array when API returns empty array' do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      expect(source.fetch).to eq([])
    end

    it 'raises ApiError on HTTP failure' do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 500, body: 'Server Error')

      expect { source.fetch }.to raise_error(Skywatch::ApiError)
    end
  end
end
