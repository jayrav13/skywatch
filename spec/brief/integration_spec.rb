# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Skywatch.brief integration' do
  let(:metar) do
    Skywatch::Briefer::Models::Metar.new(
      raw: 'KCDW 271800Z 27008KT 10SM FEW050 22/15 A3001',
      station_id: 'KCDW',
      observed_at: Time.utc(2026, 4, 27, 18),
      latitude: 40.875,
      longitude: -74.282,
      visibility_sm: 10,
      sky_condition: [{ cover: :few, base_ft: 5000 }],
      temperature_c: 22, dewpoint_c: 15
    )
  end
  let(:afd) do
    Skywatch::Briefer::Models::Afd.new(
      wfo: 'OKX', product_name: 'Area Forecast Discussion',
      issued_at: Time.utc(2026, 4, 27, 14),
      text: 'SYNOPSIS...High pressure builds in.'
    )
  end

  before do
    allow_any_instance_of(Skywatch::Briefer::Sources::Metar).to receive(:fetch).and_return([metar])
    allow_any_instance_of(Skywatch::Briefer::Sources::Taf).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Pirep).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::WindsAloft).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Sigmet).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Airmet).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Briefer::Sources::Afd).to receive(:fetch).and_return(afd)
    allow_any_instance_of(Skywatch::Nimbus::Sources::Alerts).to receive(:fetch).and_return([])
    allow_any_instance_of(Skywatch::Nimbus::Sources::StormReport).to receive(:fetch).and_return([])
    allow(Skywatch::Brief::Analysis::AirportLocator).to receive(:wfo_for).and_return('OKX')
  end

  it 'produces an AIM-9-aligned envelope' do
    hash = Skywatch.brief(airport: 'KCDW').to_h

    expect(hash[:airport]).to eq('KCDW')
    expect(hash[:coordinates]).to eq([40.875, -74.282])
    expect(hash[:wfo]).to eq('OKX')
    expect(hash[:aim_section]).to eq('7-1-5')

    aim9 = %i[adverse_conditions vfr_not_recommended synopsis current_conditions
              enroute_forecast destination_forecast winds_aloft notams atc_delays]
    aim9.each do |slot|
      expect(hash[slot]).to include(:available), "slot #{slot} missing :available"
    end

    # Six slots fillable in MVP: 2 truly populated here, 2 gracefully unavailable
    # (TAF / winds), 4 statically unavailable, plus AFD supplementary.
    expect(hash[:adverse_conditions][:available]).to be true
    expect(hash[:adverse_conditions][:items]).to eq([])
    expect(hash[:adverse_conditions][:partial_failures]).to eq([])

    expect(hash[:vfr_not_recommended][:available]).to be true
    expect(hash[:vfr_not_recommended][:vfr_not_recommended]).to be false
    expect(hash[:vfr_not_recommended][:category]).to eq('VFR')

    expect(hash[:current_conditions][:available]).to be true
    expect(hash[:current_conditions][:metar][:station_id]).to eq('KCDW')

    expect(hash[:destination_forecast][:available]).to be false
    expect(hash[:winds_aloft][:available]).to be false

    expect(hash[:synopsis]).to eq(Skywatch::Brief::Models::Brief::SYNOPSIS_UNAVAILABLE)
    expect(hash[:enroute_forecast]).to eq(Skywatch::Brief::Models::Brief::ENROUTE_UNAVAILABLE)
    expect(hash[:notams]).to eq(Skywatch::Brief::Models::Brief::NOTAMS_UNAVAILABLE)
    expect(hash[:atc_delays]).to eq(Skywatch::Brief::Models::Brief::ATC_DELAYS_UNAVAILABLE)

    expect(hash[:afd][:available]).to be true
    expect(hash[:afd][:wfo]).to eq('OKX')
    expect(hash[:afd][:text]).to include('SYNOPSIS')
  end

  it 'serializes round-trip through JSON without raising' do
    json = Skywatch.brief(airport: 'KCDW').to_json
    parsed = JSON.parse(json)
    expect(parsed['aim_section']).to eq('7-1-5')
  end
end
