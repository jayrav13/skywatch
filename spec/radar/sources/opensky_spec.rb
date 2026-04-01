# frozen_string_literal: true

RSpec.describe Skywatch::Radar::Sources::Opensky do
  subject(:source) { described_class.new }

  let(:bbox_response) { File.read('spec/fixtures/opensky/states_bbox.json') }
  let(:callsign_response) { File.read('spec/fixtures/opensky/states_callsign.json') }
  let(:icao24_response) { File.read('spec/fixtures/opensky/states_icao24.json') }

  describe '#states_bbox' do
    before do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('lamin' => '37.0', 'lamax' => '38.0'))
        .to_return(status: 200, body: bbox_response,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns StateVector models' do
      vectors = source.states_bbox(lamin: 37.0, lamax: 38.0, lomin: -123.0, lomax: -122.0)
      expect(vectors).to all(be_a(Skywatch::Radar::Models::StateVector))
      expect(vectors.size).to eq(3)
    end

    it 'parses callsigns correctly' do
      vectors = source.states_bbox(lamin: 37.0, lamax: 38.0, lomin: -123.0, lomax: -122.0)
      expect(vectors.first.callsign).to eq('UAL1234')
    end
  end

  describe '#states_by_callsign' do
    before do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .to_return(status: 200, body: bbox_response,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'filters by callsign (case-insensitive)' do
      vectors = source.states_by_callsign('UAL1234')
      expect(vectors.size).to eq(1)
      expect(vectors.first.callsign).to eq('UAL1234')
    end

    it 'returns empty array for no match' do
      vectors = source.states_by_callsign('NONEXISTENT')
      expect(vectors).to eq([])
    end
  end

  describe '#states_by_icao24' do
    before do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('icao24' => 'a12345'))
        .to_return(status: 200, body: icao24_response,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns StateVector for icao24' do
      vectors = source.states_by_icao24('a12345')
      expect(vectors.size).to eq(1)
      expect(vectors.first.icao24).to eq('a12345')
    end
  end

  describe 'empty states response' do
    before do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .to_return(status: 200, body: '{"time":1234,"states":null}',
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns empty array when states is null' do
      vectors = source.states_by_callsign('UAL1234')
      expect(vectors).to eq([])
    end
  end
end
