# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Airmet do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:gairmet_data) { JSON.parse(File.read('spec/fixtures/airmets/gairmet.json')) }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
      .with(query: { format: 'json' })
      .to_return(status: 200, body: gairmet_data.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch' do
    it 'returns an array of Airmet models' do
      airmets = source.fetch
      expect(airmets).to all(be_a(Skywatch::Briefer::Models::Airmet))
    end

    it 'returns all active AIRMETs' do
      airmets = source.fetch
      expect(airmets.size).to eq(3)
    end

    it 'returns all three products' do
      expect(source.fetch.map(&:product)).to contain_exactly(:sierra, :tango, :zulu)
    end

    it 'maps fields correctly' do
      airmet = source.fetch.first
      expect(airmet.tag).to eq('1E')
      expect(airmet.product).to eq(:sierra)
      expect(airmet.hazard).to eq('IFR')
      expect(airmet.due_to).to eq('CIG BLW 010/VIS BLW 3SM PCPN/BR/FG')
    end

    it 'parses coords into Position objects' do
      airmet = source.fetch.first
      expect(airmet.coords).not_to be_empty
      expect(airmet.coords.first).to be_a(Skywatch::Shared::Position)
    end

    it 'returns empty array when API returns empty array' do
      stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      expect(source.fetch).to eq([])
    end

    it 'raises ApiError on HTTP failure' do
      stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
        .with(query: { format: 'json' })
        .to_return(status: 500, body: 'Server Error')

      expect { source.fetch }.to raise_error(Skywatch::ApiError)
    end
  end
end
