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
  let(:smoke_source) { instance_double(Skywatch::Nimbus::Sources::Smoke, fetch: []) }

  before do
    allow(Skywatch::Brief::Analysis::AirportLocator).to receive(:wfo_for).and_return('OKX')
  end

  let(:composer) do
    described_class.new(
      metar_source: metar_source, taf_source: taf_source, pirep_source: pirep_source,
      winds_source: winds_source, sigmet_source: sigmet_source, airmet_source: airmet_source,
      afd_source: afd_source, alerts_source: alerts_source, storm_source: storm_source,
      smoke_source: smoke_source
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

  context 'error wrapping' do
    it 'sets destination_forecast unavailable when TAF source raises' do
      allow(taf_source).to receive(:fetch).and_raise(Skywatch::ApiError, 'HTTP 500')
      slot = composer.compose(airport: 'KCDW').destination_forecast
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('fetch failed')
      expect(slot[:reason]).to include('HTTP 500')
    end

    it 'sets winds_aloft unavailable when winds source raises' do
      allow(winds_source).to receive(:fetch).and_raise(StandardError, 'boom')
      slot = composer.compose(airport: 'KCDW').winds_aloft
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('fetch failed')
    end

    it 'sets afd unavailable when WFO lookup raises' do
      allow(Skywatch::Brief::Analysis::AirportLocator)
        .to receive(:wfo_for).and_raise(Skywatch::Error, 'lookup boom')
      brief = composer.compose(airport: 'KCDW')
      expect(brief.afd[:available]).to be false
      expect(brief.afd[:reason]).to include('fetch failed')
      expect(brief.wfo).to be_nil
    end

    it 'sets afd unavailable when AFD fetch raises' do
      allow(afd_source).to receive(:fetch).and_raise(Skywatch::Error, 'no AFD')
      slot = composer.compose(airport: 'KCDW').afd
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('fetch failed')
    end

    it 'records partial_failures on adverse_conditions when one sub-source raises' do
      allow(sigmet_source).to receive(:fetch).and_raise(StandardError, 'sigmet boom')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be true
      expect(slot[:partial_failures]).to contain_exactly(
        hash_including(source: 'sigmet', reason: a_string_including('sigmet boom'))
      )
    end

    it 'records smoke partial_failure when smoke source raises' do
      allow(smoke_source).to receive(:fetch).and_raise(StandardError, 'smoke boom')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be true
      expect(slot[:partial_failures]).to contain_exactly(
        hash_including(source: 'smoke', reason: a_string_including('smoke boom'))
      )
    end

    it 'surfaces a smoke plume under items when smoke source returns one' do
      feature = JSON.parse(File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json'))
                    .fetch('features').first
      plume = Skywatch::Nimbus::Models::Smoke.from_arcgis_feature(feature)
      allow(smoke_source).to receive(:fetch).and_return([plume])
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be true
      expect(slot[:items].map { |i| i[:kind] }).to include('smoke')
    end

    it 'sets adverse_conditions unavailable when every sub-source raises' do
      allow(sigmet_source).to receive(:fetch).and_raise(StandardError, 'a')
      allow(airmet_source).to receive(:fetch).and_raise(StandardError, 'b')
      allow(pirep_source).to receive(:fetch).and_raise(StandardError, 'c')
      allow(alerts_source).to receive(:fetch).and_raise(StandardError, 'd')
      allow(storm_source).to receive(:fetch).and_raise(StandardError, 'e')
      allow(smoke_source).to receive(:fetch).and_raise(StandardError, 'f')
      slot = composer.compose(airport: 'KCDW').adverse_conditions
      expect(slot[:available]).to be false
      expect(slot[:reason]).to include('all adverse sources failed')
    end

    it 'still raises hard when METAR fails (no wrapping)' do
      allow(metar_source).to receive(:fetch).and_raise(Skywatch::ApiError, 'HTTP 404')
      expect { composer.compose(airport: 'KZZZ') }.to raise_error(Skywatch::ApiError)
    end
  end

  context 'departing_at (ETD) support' do
    let(:now) { Time.utc(2026, 5, 1, 12, 0, 0) }

    let(:group_now) do
      Skywatch::Briefer::Models::TafGroup.new(
        time_from: Time.utc(2026, 5, 1, 12, 0, 0),
        time_to: Time.utc(2026, 5, 1, 15, 0, 0),
        change_type: :initial, wind_direction_deg: 270, wind_speed_kt: 10,
        visibility_sm: 10, sky_condition: []
      )
    end

    let(:group_etd) do
      Skywatch::Briefer::Models::TafGroup.new(
        time_from: Time.utc(2026, 5, 1, 15, 0, 0),
        time_to: Time.utc(2026, 5, 1, 18, 0, 0),
        change_type: :fm, wind_direction_deg: 180, wind_speed_kt: 15,
        visibility_sm: 5, sky_condition: []
      )
    end

    let(:taf) do
      Skywatch::Briefer::Models::Taf.new(
        station_id: 'KCDW', raw: 'TAF KCDW ...', issued_at: Time.utc(2026, 5, 1, 11, 0, 0),
        valid_from: Time.utc(2026, 5, 1, 12, 0, 0), valid_to: Time.utc(2026, 5, 2, 12, 0, 0),
        forecast_groups: [group_now, group_etd]
      )
    end

    let(:winds_forecast) do
      Skywatch::Briefer::Models::WindsAloft.new(
        station_id: 'KCDW', altitude_ft: 6000, wind_direction_deg: 270,
        wind_speed_kt: 25, temperature_c: 5
      )
    end

    before do
      allow(taf_source).to receive(:fetch).and_return([taf])
    end

    it 'sets departing_at on the returned brief' do
      etd = Time.utc(2026, 5, 1, 16, 0, 0)
      brief = composer.compose(airport: 'KCDW', departing_at: etd)
      expect(brief.departing_at).to eq(etd)
    end

    it 'selects the TAF group active at ETD for destination_forecast' do
      etd = Time.utc(2026, 5, 1, 16, 0, 0) # falls in group_etd window
      brief = composer.compose(airport: 'KCDW', departing_at: etd)
      slot = brief.destination_forecast
      expect(slot[:available]).to be true
      # group_etd has wind_direction_deg 180
      expect(slot[:taf][:forecast_groups].first[:wind_direction_deg]).to eq(180)
    end

    it 'falls back to first TAF group with a note when ETD is outside valid window' do
      etd = Time.utc(2026, 5, 3, 0, 0, 0) # beyond valid_to
      brief = composer.compose(airport: 'KCDW', departing_at: etd)
      slot = brief.destination_forecast
      expect(slot[:available]).to be true
      expect(slot[:note]).to match(/ETD outside TAF valid window/)
      # fallback = first group = group_now with wind_direction_deg 270
      expect(slot[:taf][:forecast_groups].first[:wind_direction_deg]).to eq(270)
    end

    it 'uses fcst 06 when ETD is within 6 hours' do
      etd = now + (3 * 3600) # 3 hours from now
      expect(winds_source).to receive(:fetch).with('KCDW', fcst: '06').and_return([winds_forecast])
      composer.compose(airport: 'KCDW', departing_at: etd)
    end

    it 'uses fcst 12 when ETD is 6-18 hours away' do
      etd = now + (10 * 3600)  # 10 hours from now
      expect(winds_source).to receive(:fetch).with('KCDW', fcst: '12').and_return([winds_forecast])
      allow(Time).to receive(:now).and_return(now)
      composer.compose(airport: 'KCDW', departing_at: etd)
    end

    it 'uses fcst 24 when ETD is more than 18 hours away' do
      etd = now + (20 * 3600)  # 20 hours from now
      expect(winds_source).to receive(:fetch).with('KCDW', fcst: '24').and_return([winds_forecast])
      allow(Time).to receive(:now).and_return(now)
      composer.compose(airport: 'KCDW', departing_at: etd)
    end

    it 'uses default fcst 06 when no ETD is given' do
      expect(winds_source).to receive(:fetch).with('KCDW', fcst: '06').and_return([winds_forecast])
      composer.compose(airport: 'KCDW')
    end

    it 'departing_at is nil on brief when not given' do
      brief = composer.compose(airport: 'KCDW')
      expect(brief.departing_at).to be_nil
    end

    it 'works with coordinate input too' do
      etd = Time.utc(2026, 5, 1, 16, 0, 0)
      allow(metar_source).to receive(:fetch_nearest)
        .with(lat: 40.875, lon: -74.282).and_return(metar)
      brief = composer.compose(at: [40.875, -74.282], departing_at: etd)
      expect(brief.departing_at).to eq(etd)
    end
  end

  context 'coordinate input' do
    it 'requires exactly one of airport: or at:' do
      expect { composer.compose }.to raise_error(ArgumentError, /airport|at/)
      expect { composer.compose(airport: 'KCDW', at: [40.0, -74.0]) }
        .to raise_error(ArgumentError, /airport|at/)
    end

    it 'composes a brief from the nearest reporting station when at: is given' do
      allow(metar_source).to receive(:fetch_nearest)
        .with(lat: 40.875, lon: -74.282).and_return(metar)
      brief = composer.compose(at: [40.875, -74.282])
      expect(brief.airport).to eq('KCDW')
      expect(brief.coordinates).to eq([40.875, -74.282])
      expect(brief.note).to include('KCDW')
    end

    it 'flags the note when nearest station is more than 25 nm away' do
      far_metar = Skywatch::Briefer::Models::Metar.new(
        station_id: 'KFAR', latitude: 41.5, longitude: -75.0,
        visibility_sm: 10, sky_condition: [{ cover: :few, base_ft: 5000 }]
      )
      allow(metar_source).to receive(:fetch_nearest).and_return(far_metar)
      brief = composer.compose(at: [40.5, -74.0])
      expect(brief.note).to match(/nearest reporting station/i)
      expect(brief.note).to match(/\d+(\.\d+)?\s*nm/)
    end

    it 'raises when no METAR is reported within the search bbox' do
      allow(metar_source).to receive(:fetch_nearest).and_return(nil)
      expect { composer.compose(at: [60.0, -150.0]) }
        .to raise_error(Skywatch::Error, /no METAR/i)
    end

    it 'uses requested coordinates (not station coordinates) for adverse-conditions polygon checks' do
      # Sigmet polygon contains the requested point (40.5,-74.5) but NOT the station (40.875,-74.282)
      allow(metar_source).to receive(:fetch_nearest).and_return(metar)
      sigmet_at_request = Skywatch::Briefer::Models::Sigmet.new(coords: [
                                                                  Skywatch::Shared::Position.new(lat: 40.6, lon: -75.5),
                                                                  Skywatch::Shared::Position.new(lat: 40.6, lon: -73.5),
                                                                  Skywatch::Shared::Position.new(lat: 39.5, lon: -73.5),
                                                                  Skywatch::Shared::Position.new(lat: 39.5, lon: -75.5),
                                                                  Skywatch::Shared::Position.new(lat: 40.6, lon: -75.5)
                                                                ])
      allow(sigmet_source).to receive(:fetch).and_return([sigmet_at_request])
      brief = composer.compose(at: [40.5, -74.5])
      kinds = brief.adverse_conditions[:items].map { |i| i[:kind] }
      expect(kinds).to include('sigmet')
    end
  end

  context 'route input (from: + to:)' do
    let(:metar_kacy) do
      Skywatch::Briefer::Models::Metar.new(
        station_id: 'KACY', latitude: 39.457, longitude: -74.577,
        visibility_sm: 10, sky_condition: [{ cover: :few, base_ft: 5000 }]
      )
    end

    before do
      # from: KCDW fetches metar (already set via let(:metar))
      # to: KACY fetches metar_kacy
      allow(metar_source).to receive(:fetch).with('KCDW').and_return([metar])
      allow(metar_source).to receive(:fetch).with('KACY').and_return([metar_kacy])
    end

    it 'raises when from: is given without to:' do
      expect { composer.compose(from: 'KCDW') }
        .to raise_error(ArgumentError, /from.*to|to.*from/i)
    end

    it 'raises when to: is given without from:' do
      expect { composer.compose(to: 'KACY') }
        .to raise_error(ArgumentError, /from.*to|to.*from/i)
    end

    it 'raises when from:/to: are mixed with at:' do
      expect { composer.compose(from: 'KCDW', to: 'KACY', at: [40.5, -74.0]) }
        .to raise_error(ArgumentError, /at/)
    end

    it 'returns a Brief anchored at the from airport' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      expect(brief.airport).to eq('KCDW')
      expect(brief.coordinates).to eq([40.875, -74.282])
    end

    it 'populates destination field with to airport metadata' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      dest = brief.destination
      expect(dest).not_to be_nil
      expect(dest[:airport]).to eq('KACY')
      expect(dest[:coordinates]).to eq([39.457, -74.577])
      expect(dest[:distance_nm]).to be_a(Numeric)
      expect(dest[:bearing_deg]).to be_a(Numeric)
    end

    it 'includes destination field in to_h for route brief' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      expect(brief.to_h).to include(:destination)
      expect(brief.to_h[:destination][:airport]).to eq('KACY')
    end

    it 'does not include destination in to_h for single-airport brief' do
      brief = composer.compose(airport: 'KCDW')
      expect(brief.to_h).not_to include(:destination)
    end

    it 'computes southerly bearing from KCDW to KACY' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      bearing = brief.destination[:bearing_deg]
      expect(bearing).to be_between(170, 210)
    end

    it 'populates enroute_forecast with available: true' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      enroute = brief.enroute_forecast
      expect(enroute[:available]).to be true
    end

    it 'includes corridor metadata in enroute_forecast' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      corridor = brief.enroute_forecast[:corridor]
      expect(corridor[:waypoints]).to be > 1
      expect(corridor[:spacing_nm]).to eq(25)
      expect(corridor[:distance_nm]).to be_a(Numeric)
      expect(corridor[:bearing_deg]).to be_a(Numeric)
    end

    it 'enroute_forecast has items and partial_failures keys' do
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      enroute = brief.enroute_forecast
      expect(enroute).to include(:items, :partial_failures)
    end

    it 'uses the to-airport TAF for destination_forecast' do
      taf_kacy = Skywatch::Briefer::Models::Taf.new(
        station_id: 'KACY', raw: 'TAF KACY ...', issued_at: Time.utc(2026, 5, 1, 11),
        valid_from: Time.utc(2026, 5, 1, 12), valid_to: Time.utc(2026, 5, 2, 12),
        forecast_groups: []
      )
      allow(taf_source).to receive(:fetch).with('KACY').and_return([taf_kacy])
      allow(taf_source).to receive(:fetch).with('KCDW').and_return([])

      brief = composer.compose(from: 'KCDW', to: 'KACY')
      expect(brief.destination_forecast[:available]).to be true
      expect(brief.destination_forecast[:taf][:station_id]).to eq('KACY')
    end

    it 'enroute_forecast includes a SIGMET that intersects the corridor' do
      # Build a wide sigmet that covers the entire KCDW-KACY corridor
      corridor_sigmet = Skywatch::Briefer::Models::Sigmet.new(coords: [
                                                                Skywatch::Shared::Position.new(lat: 41.5, lon: -75.5),
                                                                Skywatch::Shared::Position.new(lat: 41.5, lon: -73.5),
                                                                Skywatch::Shared::Position.new(lat: 38.5, lon: -73.5),
                                                                Skywatch::Shared::Position.new(lat: 38.5, lon: -75.5),
                                                                Skywatch::Shared::Position.new(lat: 41.5, lon: -75.5)
                                                              ])
      allow(sigmet_source).to receive(:fetch).and_return([corridor_sigmet])
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      kinds = brief.enroute_forecast[:items].map { |i| i[:kind] }
      expect(kinds).to include('sigmet')
    end

    it 'deduplicates sigmets that cover multiple waypoints' do
      corridor_sigmet = Skywatch::Briefer::Models::Sigmet.new(coords: [
                                                                Skywatch::Shared::Position.new(lat: 41.5, lon: -75.5),
                                                                Skywatch::Shared::Position.new(lat: 41.5, lon: -73.5),
                                                                Skywatch::Shared::Position.new(lat: 38.5, lon: -73.5),
                                                                Skywatch::Shared::Position.new(lat: 38.5, lon: -75.5),
                                                                Skywatch::Shared::Position.new(lat: 41.5, lon: -75.5)
                                                              ])
      allow(sigmet_source).to receive(:fetch).and_return([corridor_sigmet])
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      sigmet_items = brief.enroute_forecast[:items].select { |i| i[:kind] == 'sigmet' }
      expect(sigmet_items.size).to eq(1)
    end

    it 'records partial_failure in enroute_forecast when sigmet source raises' do
      allow(sigmet_source).to receive(:fetch).and_raise(StandardError, 'sigmet down')
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      failures = brief.enroute_forecast[:partial_failures]
      expect(failures).to include(hash_including(source: 'sigmet'))
    end

    it 'records partial_failure in enroute_forecast when airmet source raises' do
      allow(airmet_source).to receive(:fetch).and_raise(StandardError, 'airmet down')
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      failures = brief.enroute_forecast[:partial_failures]
      expect(failures).to include(hash_including(source: 'airmet'))
    end

    it 'adverse_conditions is still origin-point-based (not corridor-based)' do
      # Confirm adverse_conditions is computed for KCDW origin, not the corridor
      brief = composer.compose(from: 'KCDW', to: 'KACY')
      expect(brief.adverse_conditions[:available]).to be true
    end

    it 'passes departing_at through to the route brief' do
      etd = Time.utc(2026, 5, 1, 16, 0, 0)
      brief = composer.compose(from: 'KCDW', to: 'KACY', departing_at: etd)
      expect(brief.departing_at).to eq(etd)
    end
  end
end
