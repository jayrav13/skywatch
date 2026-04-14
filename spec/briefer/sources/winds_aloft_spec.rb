# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::WindsAloft do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:winds_text) { File.read('spec/fixtures/winds_aloft/low_level.txt') }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/windtemp')
      .with(query: { region: 'all', level: 'low', fcst: '06', format: 'json' })
      .to_return(status: 200, body: winds_text, headers: { 'Content-Type' => 'text/plain' })
  end

  describe '#fetch' do
    it 'fetches winds for a station at all altitudes that have data' do
      winds = source.fetch('JFK')
      expect(winds).to all(be_a(Skywatch::Briefer::Models::WindsAloft))
      expect(winds.first.station_id).to eq('JFK')
      expect(winds.map(&:altitude_ft)).not_to include(3000)
      expect(winds.map(&:altitude_ft)).to include(6000, 9000, 12_000, 18_000, 24_000, 30_000, 34_000, 39_000)
    end

    it 'parses the 6000ft column correctly for JFK (280° @ 23kt, +9°C)' do
      winds = source.fetch('JFK', altitude_ft: 6000)
      expect(winds.size).to eq(1)
      w = winds.first
      expect(w.wind_direction_deg).to eq(280)
      expect(w.wind_speed_kt).to eq(23)
      expect(w.temperature_c).to eq(9)
    end

    it 'parses high-altitude implied-negative temps (ACK 30000ft: 300°@55kt, -41°C)' do
      winds = source.fetch('ACK', altitude_ft: 30_000)
      w = winds.first
      expect(w.wind_direction_deg).to eq(300)
      expect(w.wind_speed_kt).to eq(55)
      expect(w.temperature_c).to eq(-41)
    end

    it 'returns empty for unknown station' do
      expect(source.fetch('XXXX')).to eq([])
    end

    it 'is case-insensitive on station id' do
      expect(source.fetch('jfk')).not_to be_empty
    end
  end
end
