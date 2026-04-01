# frozen_string_literal: true

RSpec.describe Skywatch::Radar::Analysis::Proximity do
  describe '.bbox' do
    it 'returns a bounding box hash around a lat/lon' do
      box = described_class.bbox(37.6213, -122.379, radius_nm: 50)

      expect(box).to have_key(:lamin)
      expect(box).to have_key(:lamax)
      expect(box).to have_key(:lomin)
      expect(box).to have_key(:lomax)
      expect(box[:lamin]).to be < 37.6213
      expect(box[:lamax]).to be > 37.6213
      expect(box[:lomin]).to be < -122.379
      expect(box[:lomax]).to be > -122.379
    end

    it 'produces a larger box for larger radius' do
      small = described_class.bbox(37.6213, -122.379, radius_nm: 10)
      large = described_class.bbox(37.6213, -122.379, radius_nm: 100)

      expect(large[:lamax] - large[:lamin]).to be > (small[:lamax] - small[:lamin])
    end
  end

  describe '.distance_nm' do
    it 'calculates distance between two points' do
      dist = described_class.distance_nm(37.6213, -122.379, 37.7213, -122.221)
      expect(dist).to be_within(3).of(10)
    end

    it 'returns 0 for same point' do
      dist = described_class.distance_nm(37.6213, -122.379, 37.6213, -122.379)
      expect(dist).to eq(0)
    end
  end

  describe '.within_radius' do
    let(:close_sv) do
      Skywatch::Radar::Models::StateVector.new(
        icao24: 'a12345', callsign: 'UAL1', latitude: 37.65, longitude: -122.40,
        baro_altitude_m: 5000.0, on_ground: false, velocity_ms: 100.0,
        true_track_deg: 280.0, vertical_rate_ms: 0.0, squawk: '1200', spi: false
      )
    end

    let(:far_sv) do
      Skywatch::Radar::Models::StateVector.new(
        icao24: 'b67890', callsign: 'DAL2', latitude: 40.0, longitude: -120.0,
        baro_altitude_m: 10_000.0, on_ground: false, velocity_ms: 200.0,
        true_track_deg: 90.0, vertical_rate_ms: 0.0, squawk: '1200', spi: false
      )
    end

    it 'filters state vectors to those within radius' do
      result = described_class.within_radius([close_sv, far_sv], lat: 37.6213, lon: -122.379, radius_nm: 50)
      expect(result.size).to eq(1)
      expect(result.first.callsign).to eq('UAL1')
    end

    it 'excludes vectors with nil position' do
      nil_sv = Skywatch::Radar::Models::StateVector.new(
        icao24: 'c00000', callsign: 'TST', latitude: nil, longitude: nil,
        on_ground: false, squawk: nil, spi: false
      )
      result = described_class.within_radius([nil_sv, close_sv], lat: 37.6213, lon: -122.379, radius_nm: 50)
      expect(result.size).to eq(1)
    end
  end
end
