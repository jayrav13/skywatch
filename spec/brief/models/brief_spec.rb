# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Skywatch::Brief::Models::Brief do
  let(:slot_available) { { available: true, payload: 'ok' } }
  let(:slot_unavailable) { { available: false, reason: 'fetch failed: ...' } }

  let(:brief) do
    described_class.new(
      airport: 'KCDW',
      coordinates: [40.875, -74.282],
      wfo: 'OKX',
      fetched_at: Time.utc(2026, 4, 27, 18, 32, 14),
      adverse_conditions: { available: true, items: [], partial_failures: [] },
      vfr_not_recommended: { available: true, vfr_not_recommended: false, category: 'VFR',
                             explanation: 'VFR conditions' },
      current_conditions: { available: true, metar: { station_id: 'KCDW' }, pireps: [] },
      destination_forecast: slot_available,
      winds_aloft: slot_available,
      afd: slot_available
    )
  end

  it 'serializes the AIM-9 envelope in canonical order' do
    hash = brief.to_h
    expect(hash[:airport]).to eq('KCDW')
    expect(hash[:coordinates]).to eq([40.875, -74.282])
    expect(hash[:wfo]).to eq('OKX')
    expect(hash[:fetched_at]).to eq('2026-04-27T18:32:14Z')
    expect(hash[:aim_section]).to eq('7-1-5')
  end

  it 'includes every AIM 7-1-5 slot' do
    hash = brief.to_h
    %i[adverse_conditions vfr_not_recommended synopsis current_conditions
       enroute_forecast destination_forecast winds_aloft notams atc_delays].each do |slot|
      expect(hash).to include(slot), "missing slot: #{slot}"
    end
  end

  it 'includes the supplementary afd slot' do
    expect(brief.to_h).to include(:afd)
  end

  it 'hardcodes synopsis as unavailable with afd-pointer reason' do
    expect(brief.to_h[:synopsis]).to eq(
      available: false,
      reason: 'no synopsis source in skywatch — see afd slot'
    )
  end

  it 'hardcodes enroute_forecast as unavailable with route-deferred reason' do
    expect(brief.to_h[:enroute_forecast]).to eq(
      available: false,
      reason: 'single-point brief; route input deferred from MVP'
    )
  end

  it 'hardcodes notams as unavailable with sectional-domain reason' do
    expect(brief.to_h[:notams]).to eq(
      available: false,
      reason: 'NOTAMs not in skywatch yet — Sectional domain not yet built'
    )
  end

  it 'hardcodes atc_delays as unavailable' do
    expect(brief.to_h[:atc_delays]).to eq(
      available: false,
      reason: 'ATC delays not in skywatch yet — no source'
    )
  end

  it 'preserves the AIM-9 slots in canonical order' do
    keys = brief.to_h.keys
    aim9 = %i[adverse_conditions vfr_not_recommended synopsis current_conditions
              enroute_forecast destination_forecast winds_aloft notams atc_delays]
    expect(keys & aim9).to eq(aim9)
  end

  it 'serializes to JSON' do
    expect { JSON.parse(brief.to_json) }.not_to raise_error
  end

  describe 'note (coord-query metadata)' do
    it 'is omitted from to_h when nil (default)' do
      expect(brief.to_h).not_to include(:note)
    end

    it 'is included in to_h when set' do
      coord_brief = described_class.new(
        airport: 'KCDW',
        coordinates: [40.7, -74.2],
        wfo: 'OKX',
        fetched_at: Time.utc(2026, 4, 27, 18, 32, 14),
        adverse_conditions: { available: true, items: [], partial_failures: [] },
        vfr_not_recommended: slot_available,
        current_conditions: slot_available,
        destination_forecast: slot_available,
        winds_aloft: slot_available,
        afd: slot_available,
        note: 'data sourced from KCDW (12.0 nm from requested point)'
      )
      expect(coord_brief.to_h[:note]).to eq('data sourced from KCDW (12.0 nm from requested point)')
    end
  end

  describe 'departing_at' do
    it 'is nil by default' do
      expect(brief.departing_at).to be_nil
    end

    it 'is always present in to_h (even when nil)' do
      expect(brief.to_h).to include(:departing_at)
      expect(brief.to_h[:departing_at]).to be_nil
    end

    it 'serializes as ISO8601 string when set' do
      etd = Time.utc(2026, 5, 1, 14, 30, 0)
      etd_brief = described_class.new(
        airport: 'KCDW',
        coordinates: [40.875, -74.282],
        wfo: 'OKX',
        fetched_at: Time.utc(2026, 5, 1, 12, 0, 0),
        adverse_conditions: { available: true, items: [], partial_failures: [] },
        vfr_not_recommended: slot_available,
        current_conditions: slot_available,
        destination_forecast: slot_available,
        winds_aloft: slot_available,
        afd: slot_available,
        departing_at: etd
      )
      expect(etd_brief.departing_at).to eq(etd)
      expect(etd_brief.to_h[:departing_at]).to eq('2026-05-01T14:30:00Z')
    end
  end

  describe 'destination (route briefs)' do
    let(:destination_field) do
      { airport: 'KACY', coordinates: [39.457, -74.577], distance_nm: 86.2, bearing_deg: 192.3 }
    end

    let(:route_brief) do
      described_class.new(
        airport: 'KCDW',
        coordinates: [40.875, -74.282],
        wfo: 'OKX',
        fetched_at: Time.utc(2026, 5, 1, 12, 0, 0),
        adverse_conditions: { available: true, items: [], partial_failures: [] },
        vfr_not_recommended: slot_available,
        current_conditions: slot_available,
        destination_forecast: slot_available,
        winds_aloft: slot_available,
        afd: slot_available,
        destination: destination_field
      )
    end

    it 'is nil by default on non-route briefs' do
      expect(brief.destination).to be_nil
    end

    it 'is omitted from to_h when nil (non-route brief)' do
      expect(brief.to_h).not_to include(:destination)
    end

    it 'is included in to_h when set (route brief)' do
      hash = route_brief.to_h
      expect(hash).to include(:destination)
      expect(hash[:destination][:airport]).to eq('KACY')
      expect(hash[:destination][:coordinates]).to eq([39.457, -74.577])
      expect(hash[:destination][:distance_nm]).to eq(86.2)
      expect(hash[:destination][:bearing_deg]).to eq(192.3)
    end
  end

  describe 'enroute_forecast (route briefs)' do
    it 'defaults to ENROUTE_UNAVAILABLE constant when not given' do
      expect(brief.to_h[:enroute_forecast]).to eq(
        available: false,
        reason: 'single-point brief; route input deferred from MVP'
      )
    end

    it 'uses the provided enroute_forecast when set' do
      enroute_data = { available: true, items: [], partial_failures: [], corridor: { waypoints: 4 } }
      route_brief = described_class.new(
        airport: 'KCDW',
        coordinates: [40.875, -74.282],
        wfo: 'OKX',
        fetched_at: Time.utc(2026, 5, 1, 12, 0, 0),
        adverse_conditions: { available: true, items: [], partial_failures: [] },
        vfr_not_recommended: slot_available,
        current_conditions: slot_available,
        destination_forecast: slot_available,
        winds_aloft: slot_available,
        afd: slot_available,
        enroute_forecast: enroute_data
      )
      expect(route_brief.enroute_forecast).to eq(enroute_data)
      expect(route_brief.to_h[:enroute_forecast]).to eq(enroute_data)
    end

    it 'does not use the constant when enroute_forecast is explicitly provided' do
      enroute_data = { available: true, items: [], partial_failures: [], corridor: {} }
      route_brief = described_class.new(
        airport: 'KCDW',
        coordinates: [40.875, -74.282],
        wfo: 'OKX',
        fetched_at: Time.utc(2026, 5, 1, 12, 0, 0),
        adverse_conditions: { available: true, items: [], partial_failures: [] },
        vfr_not_recommended: slot_available,
        current_conditions: slot_available,
        destination_forecast: slot_available,
        winds_aloft: slot_available,
        afd: slot_available,
        enroute_forecast: enroute_data
      )
      expect(route_brief.to_h[:enroute_forecast]).not_to include(:reason)
    end
  end
end
