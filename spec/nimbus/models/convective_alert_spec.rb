# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'rgeo/geo_json'

RSpec.describe Skywatch::Nimbus::Models::ConvectiveAlert do
  describe 'construction and predicates' do
    it 'exposes attrs and predicates for a warning' do
      alert = described_class.new(
        id: 'urn:oid:2.49.0.1.840.0.x',
        kind: :warning,
        event: 'Tornado Warning',
        headline: 'Tornado Warning issued ... by NWS NY',
        description: 'TORNADO WARNING IN EFFECT ...',
        severity: :extreme,
        certainty: :observed,
        urgency: :immediate,
        sent_at: Time.utc(2026, 4, 25, 18, 30),
        effective_at: Time.utc(2026, 4, 25, 18, 30),
        onset_at: Time.utc(2026, 4, 25, 18, 30),
        expires_at: Time.utc(2026, 4, 25, 19, 30),
        ends_at: Time.utc(2026, 4, 25, 19, 30),
        area_description: 'Essex, NJ',
        geometry: nil,
        hail_size_in: 1.5,
        wind_gust_mph: 65.0,
        wind_gust_kt: 56.5,
        tornado_detection: :radar_indicated,
        thunderstorm_damage_threat: :considerable,
        flash_flood_damage_threat: nil,
        raw_parameters: {}
      )

      expect(alert.warning?).to be true
      expect(alert.watch?).to be false
      expect(alert.event).to eq('Tornado Warning')
      expect(alert.severity).to eq(:extreme)
      expect(alert.hail_size_in).to eq(1.5)
    end

    it 'exposes predicates for a watch' do
      alert = described_class.new(
        id: 'x', kind: :watch, event: 'Tornado Watch',
        headline: '', description: '',
        severity: :severe, certainty: :possible, urgency: :expected,
        sent_at: nil, effective_at: nil, onset_at: nil,
        expires_at: nil, ends_at: nil,
        area_description: '', geometry: nil,
        hail_size_in: nil, wind_gust_mph: nil, wind_gust_kt: nil,
        tornado_detection: nil, thunderstorm_damage_threat: nil,
        flash_flood_damage_threat: nil, raw_parameters: {}
      )

      expect(alert.watch?).to be true
      expect(alert.warning?).to be false
    end
  end

  describe '.from_nws_feature — identity / times / geometry' do
    let(:feature) do
      JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_warning_active.json', __dir__)))
          .fetch('features').first
    end

    it 'parses identity, severity tier, times, area, and geometry' do
      alert = described_class.from_nws_feature(feature)

      expect(alert.id).to eq('urn:oid:2.49.0.1.840.0.tor-warn-1')
      expect(alert.kind).to eq(:warning)
      expect(alert.event).to eq('Tornado Warning')
      expect(alert.headline).to start_with('Tornado Warning issued')

      expect(alert.severity).to eq(:extreme)
      expect(alert.certainty).to eq(:observed)
      expect(alert.urgency).to eq(:immediate)

      expect(alert.sent_at).to eq(Time.utc(2026, 4, 25, 18, 30))
      expect(alert.effective_at).to eq(Time.utc(2026, 4, 25, 18, 30))
      expect(alert.onset_at).to eq(Time.utc(2026, 4, 25, 18, 30))
      expect(alert.expires_at).to eq(Time.utc(2026, 4, 25, 19, 30))
      expect(alert.ends_at).to eq(Time.utc(2026, 4, 25, 19, 30))

      expect(alert.area_description).to eq('Essex, NJ')
      expect(alert.geometry).to be_a(RGeo::Feature::Polygon)
    end

    it 'derives kind :watch from a watch event' do
      watch = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_watch_active.json', __dir__)))
                  .fetch('features').first
      alert = described_class.from_nws_feature(watch)

      expect(alert.kind).to eq(:watch)
      expect(alert.event).to eq('Tornado Watch')
    end

    it 'tolerates a null geometry' do
      feature = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/geometry_missing.json', __dir__)))
                    .fetch('features').first
      alert = described_class.from_nws_feature(feature)

      expect(alert.geometry).to be_nil
      expect(alert.id).not_to be_nil
    end

    it 'maps unknown severity / certainty / urgency to :unknown' do
      feature = JSON.parse(File.read(File.expand_path('../../fixtures/nws_alerts/tornado_warning_active.json',
                                                      __dir__)))
                    .fetch('features').first
      feature['properties']['severity'] = 'Wat'
      feature['properties']['certainty'] = nil
      alert = described_class.from_nws_feature(feature)

      expect(alert.severity).to eq(:unknown)
      expect(alert.certainty).to eq(:unknown)
    end
  end
end
