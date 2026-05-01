# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::AirportLocator do
  describe '.coordinates_from_metar' do
    it 'returns [lat, lon] from a METAR' do
      metar = Skywatch::Briefer::Models::Metar.new(
        station_id: 'KCDW', latitude: 40.875, longitude: -74.282
      )
      expect(described_class.coordinates_from_metar(metar)).to eq([40.875, -74.282])
    end

    it 'raises when METAR has no coordinates' do
      metar = Skywatch::Briefer::Models::Metar.new(station_id: 'KCDW')
      expect { described_class.coordinates_from_metar(metar) }
        .to raise_error(Skywatch::Error, /no coordinates on METAR/)
    end
  end

  describe '.wfo_for' do
    let(:fixture) { File.read(File.expand_path('../../fixtures/nws_points/kcdw.json', __dir__)) }

    before do
      described_class.reset!
      stub_request(:get, %r{https://api\.weather\.gov/points/40\.875,-74\.282})
        .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
    end

    it 'returns the WFO id for a coordinate' do
      expect(described_class.wfo_for(40.875, -74.282)).to eq('OKX')
    end

    it 'caches subsequent calls within TTL' do
      described_class.wfo_for(40.875, -74.282)
      described_class.wfo_for(40.875, -74.282)
      expect(WebMock).to have_requested(:get, %r{points/40\.875,-74\.282}).once
    end

    it 'raises Skywatch::Error when the points endpoint fails' do
      stub_request(:get, %r{https://api\.weather\.gov/points/0\.0,0\.0})
        .to_return(status: 500, body: 'boom')
      expect { described_class.wfo_for(0.0, 0.0) }.to raise_error(Skywatch::Error)
    end
  end
end
