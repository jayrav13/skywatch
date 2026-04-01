# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::WindsAloft do
  subject(:source) { described_class.new(client: Skywatch.client) }

  let(:winds_response) { JSON.parse(File.read('spec/fixtures/winds_aloft/low_level.json')) }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/windtemp')
      .with(query: { region: 'all', level: 'low', fcst: '06', format: 'json' })
      .to_return(status: 200, body: winds_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch' do
    it 'fetches winds for a station at all altitudes' do
      winds = source.fetch('JFK')
      expect(winds).to all(be_a(Skywatch::Briefer::Models::WindsAloft))
      expect(winds.first.station_id).to eq('JFK')
    end

    it 'filters to a specific altitude' do
      winds = source.fetch('JFK', altitude_ft: 6000)
      expect(winds.size).to eq(1)
      expect(winds.first.altitude_ft).to eq(6000)
      expect(winds.first.wind_speed_kt).to eq(35)
    end

    it 'returns empty for unknown station' do
      winds = source.fetch('XXXX')
      expect(winds).to eq([])
    end

    it 'skips nil altitude entries' do
      winds = source.fetch('ACK')
      altitudes = winds.map(&:altitude_ft)
      expect(altitudes).not_to include(24_000)
    end
  end
end
