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
end
