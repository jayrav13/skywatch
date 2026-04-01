# frozen_string_literal: true

RSpec.describe Skywatch::Radar::Formatters::Text do
  let(:sv) do
    Skywatch::Radar::Models::StateVector.new(
      icao24: 'a12345', callsign: 'UAL1234', origin_country: 'United States',
      time_position: 1_711_670_398, last_contact: 1_711_670_400,
      latitude: 37.621, longitude: -122.379,
      baro_altitude_m: 5486.4, on_ground: false,
      velocity_ms: 128.5, true_track_deg: 280.0, vertical_rate_ms: -6.5,
      geo_altitude_m: 5562.6, squawk: '1200', spi: false
    )
  end

  describe '.format_flight_row' do
    it 'returns a formatted row' do
      row = described_class.format_flight_row(sv)
      expect(row).to include('UAL1234')
      expect(row).to include('1200')
    end
  end

  describe '.format_track' do
    it 'returns a detailed track display' do
      output = described_class.format_track(sv)
      expect(output).to include('UAL1234')
      expect(output).to include('United States')
      expect(output).to include('280')
    end
  end

  describe '.format_flights_table' do
    it 'returns a header and rows' do
      output = described_class.format_flights_table([sv], label: 'KSFO (50nm)')
      expect(output).to include('KSFO')
      expect(output).to include('UAL1234')
      expect(output).to include('CALL')
    end

    it 'handles empty array' do
      output = described_class.format_flights_table([], label: 'KSFO (50nm)')
      expect(output).to include('No flights')
    end
  end
end
