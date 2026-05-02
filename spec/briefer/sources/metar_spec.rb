# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::Sources::Metar do
  subject(:source) { described_class.new(client: Skywatch::Shared::Http.new) }

  let(:kcdw_response) { [JSON.parse(File.read('spec/fixtures/metars/kcdw.json'))] }
  let(:multi_response) do
    [
      JSON.parse(File.read('spec/fixtures/metars/kcdw.json')),
      JSON.parse(File.read('spec/fixtures/metars/kewr_gusty.json'))
    ]
  end

  describe '#fetch' do
    it 'fetches a single station METAR' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW', format: 'json' })
        .to_return(status: 200, body: kcdw_response.to_json, headers: { 'Content-Type' => 'application/json' })

      metars = source.fetch('KCDW')
      expect(metars.size).to eq(1)
      expect(metars.first).to be_a(Skywatch::Briefer::Models::Metar)
      expect(metars.first.station_id).to eq('KCDW')
    end

    it 'fetches multiple stations in a single request' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW,KEWR', format: 'json' })
        .to_return(status: 200, body: multi_response.to_json, headers: { 'Content-Type' => 'application/json' })

      metars = source.fetch('KCDW', 'KEWR')
      expect(metars.size).to eq(2)
      expect(metars.map(&:station_id)).to contain_exactly('KCDW', 'KEWR')
    end

    it 'returns empty array when API returns empty array' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KXYZ', format: 'json' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      metars = source.fetch('KXYZ')
      expect(metars).to eq([])
    end

    it 'raises ApiError on HTTP failure' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW', format: 'json' })
        .to_return(status: 500, body: 'Server Error')

      expect { source.fetch('KCDW') }.to raise_error(Skywatch::ApiError)
    end

    it 'upcases station IDs' do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW', format: 'json' })
        .to_return(status: 200, body: kcdw_response.to_json, headers: { 'Content-Type' => 'application/json' })

      metars = source.fetch('kcdw')
      expect(metars.first.station_id).to eq('KCDW')
    end
  end

  describe '#fetch_nearest' do
    let(:requested_lat) { 40.875 }
    let(:requested_lon) { -74.282 }

    def stub_bbox(response)
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: hash_including(format: 'json'))
        .to_return(status: 200, body: response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns the closest METAR by great-circle distance' do
      far = JSON.parse(File.read('spec/fixtures/metars/kewr_gusty.json')) # KEWR ~16nm from KCDW
      near = JSON.parse(File.read('spec/fixtures/metars/kcdw.json'))      # KCDW (the requested point)
      stub_bbox([far, near])

      result = source.fetch_nearest(lat: requested_lat, lon: requested_lon)
      expect(result.station_id).to eq('KCDW')
    end

    it 'returns nil when no stations are reported in the bbox' do
      stub_bbox([])
      expect(source.fetch_nearest(lat: requested_lat, lon: requested_lon)).to be_nil
    end

    it 'skips stations missing lat/lon' do
      kcdw = JSON.parse(File.read('spec/fixtures/metars/kcdw.json')).merge('lat' => nil, 'lon' => nil)
      stub_bbox([kcdw])
      expect(source.fetch_nearest(lat: requested_lat, lon: requested_lon)).to be_nil
    end

    it 'sends a bbox query (not a station-id query)' do
      stub_bbox([])
      source.fetch_nearest(lat: requested_lat, lon: requested_lon)
      expect(WebMock).to have_requested(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: hash_including(:bbox, format: 'json'))
    end
  end
end
