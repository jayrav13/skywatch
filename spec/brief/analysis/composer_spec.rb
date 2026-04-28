# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Analysis::Composer do
  let(:metar) do
    Skywatch::Briefer::Models::Metar.new(
      station_id: 'KCDW', latitude: 40.875, longitude: -74.282,
      visibility_sm: 10, sky_condition: [{ cover: :few, base_ft: 5000 }]
    )
  end

  let(:metar_source) { instance_double(Skywatch::Briefer::Sources::Metar, fetch: [metar]) }
  let(:taf_source) { instance_double(Skywatch::Briefer::Sources::Taf, fetch: []) }
  let(:pirep_source) { instance_double(Skywatch::Briefer::Sources::Pirep, fetch: []) }
  let(:winds_source) { instance_double(Skywatch::Briefer::Sources::WindsAloft, fetch: []) }
  let(:sigmet_source) { instance_double(Skywatch::Briefer::Sources::Sigmet, fetch: []) }
  let(:airmet_source) { instance_double(Skywatch::Briefer::Sources::Airmet, fetch: []) }
  let(:afd_model) do
    Skywatch::Briefer::Models::Afd.new(
      wfo: 'OKX', product_name: 'Area Forecast Discussion',
      issued_at: Time.utc(2026, 4, 27, 14), text: 'SYNOPSIS...'
    )
  end
  let(:afd_source) { instance_double(Skywatch::Briefer::Sources::Afd, fetch: afd_model) }
  let(:alerts_source) { instance_double(Skywatch::Nimbus::Sources::Alerts, fetch: []) }
  let(:storm_source) { instance_double(Skywatch::Nimbus::Sources::StormReport, fetch: []) }

  before do
    allow(Skywatch::Brief::Analysis::AirportLocator).to receive(:wfo_for).and_return('OKX')
  end

  let(:composer) do
    described_class.new(
      metar_source: metar_source, taf_source: taf_source, pirep_source: pirep_source,
      winds_source: winds_source, sigmet_source: sigmet_source, airmet_source: airmet_source,
      afd_source: afd_source, alerts_source: alerts_source, storm_source: storm_source
    )
  end

  it 'returns a Brief with metadata populated' do
    brief = composer.compose(airport: 'KCDW')
    expect(brief).to be_a(Skywatch::Brief::Models::Brief)
    expect(brief.airport).to eq('KCDW')
    expect(brief.coordinates).to eq([40.875, -74.282])
    expect(brief.wfo).to eq('OKX')
    expect(brief.fetched_at).to be_a(Time)
  end

  it 'sets adverse_conditions available with empty items when nothing is adverse' do
    expect(composer.compose(airport: 'KCDW').adverse_conditions).to eq(
      available: true, items: [], partial_failures: []
    )
  end

  it 'sets vfr_not_recommended from FlightCategory' do
    slot = composer.compose(airport: 'KCDW').vfr_not_recommended
    expect(slot[:available]).to be true
    expect(slot[:vfr_not_recommended]).to be false
    expect(slot[:category]).to eq('VFR')
    expect(slot[:explanation]).to include('VFR')
  end

  it 'sets current_conditions with metar and empty pireps' do
    slot = composer.compose(airport: 'KCDW').current_conditions
    expect(slot[:available]).to be true
    expect(slot[:metar][:station_id]).to eq('KCDW')
    expect(slot[:pireps]).to eq([])
  end

  it 'sets destination_forecast unavailable when no TAF' do
    slot = composer.compose(airport: 'KCDW').destination_forecast
    expect(slot[:available]).to be false
    expect(slot[:reason]).to include('no TAF')
  end

  it 'sets winds_aloft unavailable when no winds-aloft data' do
    slot = composer.compose(airport: 'KCDW').winds_aloft
    expect(slot[:available]).to be false
    expect(slot[:reason]).to include('no winds aloft')
  end

  it 'sets afd available when AFD fetch succeeds' do
    slot = composer.compose(airport: 'KCDW').afd
    expect(slot[:available]).to be true
    expect(slot[:wfo]).to eq('OKX')
    expect(slot[:text]).to eq('SYNOPSIS...')
  end

  it 'classifies LIFR as VFR not recommended' do
    metar_lifr = Skywatch::Briefer::Models::Metar.new(
      station_id: 'KCDW', latitude: 40.875, longitude: -74.282,
      visibility_sm: 0.5, sky_condition: [{ cover: :ovc, base_ft: 200 }]
    )
    allow(metar_source).to receive(:fetch).and_return([metar_lifr])
    slot = composer.compose(airport: 'KCDW').vfr_not_recommended
    expect(slot[:vfr_not_recommended]).to be true
    expect(slot[:category]).to eq('LIFR')
  end

  it 'raises when METAR is missing' do
    allow(metar_source).to receive(:fetch).and_return([])
    expect { composer.compose(airport: 'KZZZ') }
      .to raise_error(Skywatch::Error, /no METAR for KZZZ/)
  end
end
