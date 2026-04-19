# frozen_string_literal: true

RSpec.describe Skywatch::Mayday::Sources::Emergency do
  subject(:source) { described_class.new }

  let(:fixture) { File.read('spec/fixtures/opensky/states_bbox_emergencies.json') }

  before do
    stub_request(:get, 'https://opensky-network.org/api/states/all')
      .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
      .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#near' do
    it 'returns Mayday::Models::Emergency wrapping the in-radius emergency vectors' do
      result = source.near(lat: 40.875, lon: -74.282, radius_nm: 50)
      expect(result).to all(be_a(Skywatch::Mayday::Models::Emergency))
    end

    it 'keeps the three emergency squawks that are inside the 50nm radius' do
      result = source.near(lat: 40.875, lon: -74.282, radius_nm: 50)
      expect(result.map(&:squawk)).to contain_exactly('7500', '7600', '7700')
    end

    it 'drops the normal-squawk vector' do
      result = source.near(lat: 40.875, lon: -74.282, radius_nm: 50)
      expect(result.map(&:callsign)).not_to include('NORM0001')
    end

    it 'drops emergency vectors that are inside the bbox but outside the radius' do
      result = source.near(lat: 40.875, lon: -74.282, radius_nm: 50)
      expect(result.map(&:callsign)).not_to include('FAR0005')
    end

    it 'drops vectors with nil position' do
      result = source.near(lat: 40.875, lon: -74.282, radius_nm: 50)
      expect(result.map(&:callsign)).not_to include('NUL0006')
    end

    it 'returns [] when no emergencies are in scope' do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
        .to_return(status: 200, body: { 'time' => 0, 'states' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(source.near(lat: 40.875, lon: -74.282, radius_nm: 50)).to eq([])
    end

    it 'defaults the radius to 100nm' do
      result = source.near(lat: 40.875, lon: -74.282)
      # Larger radius → FAR0005 is now included
      expect(result.map(&:callsign)).to include('FAR0005')
    end
  end
end
