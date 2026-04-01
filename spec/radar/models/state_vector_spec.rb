# frozen_string_literal: true

RSpec.describe Skywatch::Radar::Models::StateVector do
  let(:fixture) { JSON.parse(File.read('spec/fixtures/opensky/states_bbox.json')) }
  let(:row) { fixture['states'][0] }

  describe '.from_api' do
    subject(:sv) { described_class.from_api(row) }

    it 'parses identification fields' do
      expect(sv.icao24).to eq('a12345')
      expect(sv.callsign).to eq('UAL1234')
      expect(sv.origin_country).to eq('United States')
    end

    it 'parses position fields' do
      expect(sv.longitude).to be_within(0.001).of(-122.379)
      expect(sv.latitude).to be_within(0.001).of(37.621)
      expect(sv.baro_altitude_m).to be_within(0.1).of(5486.4)
      expect(sv.on_ground).to be(false)
    end

    it 'parses velocity fields' do
      expect(sv.velocity_ms).to be_within(0.1).of(128.5)
      expect(sv.true_track_deg).to be_within(0.1).of(280.0)
      expect(sv.vertical_rate_ms).to be_within(0.1).of(-6.5)
    end

    it 'parses squawk' do
      expect(sv.squawk).to eq('1200')
    end

    it 'strips whitespace from callsign' do
      expect(sv.callsign).to eq('UAL1234')
    end
  end

  describe '.from_api with nil callsign' do
    subject(:sv) { described_class.from_api(fixture['states'][2]) }

    it 'handles nil callsign' do
      expect(sv.callsign).to be_nil
    end

    it 'handles ground aircraft' do
      expect(sv.on_ground).to be(true)
    end
  end

  describe '#altitude_ft' do
    subject(:sv) { described_class.from_api(row) }

    it 'converts meters to feet' do
      expect(sv.altitude_ft).to be_within(1).of(18_001)
    end

    it 'returns nil when baro_altitude_m is nil' do
      ground = described_class.from_api(fixture['states'][2])
      expect(ground.altitude_ft).to be_nil
    end
  end

  describe '#velocity_kt' do
    subject(:sv) { described_class.from_api(row) }

    it 'converts m/s to knots' do
      expect(sv.velocity_kt).to be_within(1).of(250)
    end
  end

  describe '#vertical_rate_fpm' do
    subject(:sv) { described_class.from_api(row) }

    it 'converts m/s to ft/min' do
      expect(sv.vertical_rate_fpm).to be_within(10).of(-1280)
    end
  end

  describe '#emergency?' do
    it 'returns false for normal squawk' do
      sv = described_class.from_api(row)
      expect(sv.emergency?).to be(false)
    end

    it 'returns true for 7700' do
      emergency_row = row.dup
      emergency_row[14] = '7700'
      sv = described_class.from_api(emergency_row)
      expect(sv.emergency?).to be(true)
    end

    it 'returns true for 7600' do
      row_dup = row.dup
      row_dup[14] = '7600'
      sv = described_class.from_api(row_dup)
      expect(sv.emergency?).to be(true)
    end

    it 'returns true for 7500' do
      row_dup = row.dup
      row_dup[14] = '7500'
      sv = described_class.from_api(row_dup)
      expect(sv.emergency?).to be(true)
    end
  end

  describe '#to_h' do
    subject(:sv) { described_class.from_api(row) }

    it 'returns a hash with key fields' do
      hash = sv.to_h
      expect(hash[:icao24]).to eq('a12345')
      expect(hash[:callsign]).to eq('UAL1234')
      expect(hash[:altitude_ft]).to be_within(1).of(18_001)
      expect(hash[:velocity_kt]).to be_within(1).of(250)
    end
  end
end
