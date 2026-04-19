# frozen_string_literal: true

RSpec.describe Skywatch::Mayday::Formatters::Text do
  let(:fixture) { JSON.parse(File.read('spec/fixtures/opensky/states_bbox_emergencies.json')) }

  def emergency_for(squawk)
    row = fixture['states'].find { |r| r[14] == squawk }
    sv = Skywatch::Radar::Models::StateVector.from_api(row)
    Skywatch::Mayday::Models::Emergency.new(sv)
  end

  describe '.format_emergency' do
    it 'renders a general emergency with all flight state' do
      output = described_class.format_emergency(emergency_for('7700'))

      expect(output).to include('MAYDAY: GENERAL EMERGENCY (squawk 7700)')
      expect(output).to include('Callsign: GEN0004')
      expect(output).to include('ICAO24: a00004')
      expect(output).to include('Position: 41.0000, -74.0000')
      expect(output).to include('FL320')
      expect(output).to include('389kt')
      expect(output).to include('090°')
    end

    it 'renders the hijack label and squawk' do
      output = described_class.format_emergency(emergency_for('7500'))
      expect(output).to include('MAYDAY: HIJACK (squawk 7500)')
    end

    it 'renders the radio-failure label and squawk' do
      output = described_class.format_emergency(emergency_for('7600'))
      expect(output).to include('MAYDAY: RADIO FAILURE (squawk 7600)')
    end
  end
end
