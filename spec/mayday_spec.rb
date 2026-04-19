# frozen_string_literal: true

RSpec.describe Skywatch do
  describe '.mayday' do
    let(:fixture) { File.read('spec/fixtures/opensky/states_bbox_emergencies.json') }

    before do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns Mayday::Emergency models for in-radius emergency vectors' do
      result = described_class.mayday(lat: 40.875, lon: -74.282, radius_nm: 50)
      expect(result).to all(be_a(Skywatch::Mayday::Models::Emergency))
      expect(result.map(&:squawk)).to contain_exactly('7500', '7600', '7700')
    end

    it 'defaults the radius to 100nm' do
      result = described_class.mayday(lat: 40.875, lon: -74.282)
      expect(result.map(&:callsign)).to include('FAR0005')
    end

    it 'returns [] when there are no emergencies in scope' do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
        .to_return(status: 200, body: { 'time' => 0, 'states' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(described_class.mayday(lat: 0.0, lon: 0.0, radius_nm: 50)).to eq([])
    end
  end
end
