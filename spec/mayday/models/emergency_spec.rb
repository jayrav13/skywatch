# frozen_string_literal: true

RSpec.describe Skywatch::Mayday::Models::Emergency do
  let(:fixture) { JSON.parse(File.read('spec/fixtures/opensky/states_bbox_emergencies.json')) }

  def state_vector_for(squawk)
    row = fixture['states'].find { |r| r[14] == squawk }
    raise "fixture missing #{squawk}" unless row

    Skywatch::Radar::Models::StateVector.from_api(row)
  end

  describe '#initialize' do
    it 'wraps an emergency-squawking state vector' do
      sv = state_vector_for('7700')
      emergency = described_class.new(sv)
      expect(emergency.state_vector).to be(sv)
    end

    it 'raises ArgumentError when the vector is not emergency-squawking' do
      sv = state_vector_for('1200')
      expect { described_class.new(sv) }.to raise_error(ArgumentError, /1200/)
    end

    it 'raises ArgumentError when the vector has no squawk' do
      row = fixture['states'].find { |r| r[14] == '7700' }.dup
      row[14] = nil
      sv = Skywatch::Radar::Models::StateVector.from_api(row)
      expect { described_class.new(sv) }.to raise_error(ArgumentError)
    end
  end

  describe '#emergency_type and #label' do
    it 'classifies 7500 as :hijack / "HIJACK"' do
      e = described_class.new(state_vector_for('7500'))
      expect(e.emergency_type).to eq(:hijack)
      expect(e.label).to eq('HIJACK')
    end

    it 'classifies 7600 as :radio_failure / "RADIO FAILURE"' do
      e = described_class.new(state_vector_for('7600'))
      expect(e.emergency_type).to eq(:radio_failure)
      expect(e.label).to eq('RADIO FAILURE')
    end

    it 'classifies 7700 as :general / "GENERAL EMERGENCY"' do
      e = described_class.new(state_vector_for('7700'))
      expect(e.emergency_type).to eq(:general)
      expect(e.label).to eq('GENERAL EMERGENCY')
    end
  end

  describe 'state vector delegations' do
    subject(:emergency) { described_class.new(state_vector_for('7700')) }

    it 'delegates callsign, icao24, position, altitude, velocity, on_ground' do
      expect(emergency.callsign).to eq('GEN0004')
      expect(emergency.icao24).to eq('a00004')
      expect(emergency.latitude).to be_within(0.0001).of(41.0)
      expect(emergency.longitude).to be_within(0.0001).of(-74.0)
      expect(emergency.altitude_ft).to eq(31_988) # 9750m * 3.28084 ≈ 31988
      expect(emergency.velocity_kt).to eq(389)    # 200 m/s * 1.94384 ≈ 389
      expect(emergency.on_ground).to be(false)
    end

    it 'exposes heading_deg as the underlying true_track_deg' do
      expect(emergency.heading_deg).to eq(90.0)
    end
  end

  describe '#to_h' do
    subject(:hash) { described_class.new(state_vector_for('7500')).to_h }

    it 'includes classification fields' do
      expect(hash[:squawk]).to eq('7500')
      expect(hash[:emergency_type]).to eq(:hijack)
      expect(hash[:label]).to eq('HIJACK')
    end

    it 'includes identification and position' do
      expect(hash[:callsign]).to eq('HJK0002')
      expect(hash[:icao24]).to eq('a00002')
      expect(hash[:latitude]).to be_within(0.0001).of(40.6892)
      expect(hash[:longitude]).to be_within(0.0001).of(-74.1745)
    end

    it 'includes flight state' do
      expect(hash[:altitude_ft]).to be > 0
      expect(hash[:velocity_kt]).to be > 0
      expect(hash[:heading_deg]).to eq(270.0)
      expect(hash[:on_ground]).to be(false)
    end
  end

  describe '#to_json' do
    it 'is the JSON encoding of #to_h' do
      e = described_class.new(state_vector_for('7700'))
      expect(JSON.parse(e.to_json)).to eq(JSON.parse(e.to_h.to_json))
    end
  end
end
