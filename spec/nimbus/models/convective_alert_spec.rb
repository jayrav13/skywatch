# frozen_string_literal: true

require 'spec_helper'

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
end
