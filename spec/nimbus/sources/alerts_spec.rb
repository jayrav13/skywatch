# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe Skywatch::Nimbus::Sources::Alerts do
  let(:fixture) { File.read(File.expand_path('../../fixtures/nws_alerts/multiple_active.json', __dir__)) }

  describe '#fetch' do
    it 'requests api.weather.gov/alerts/active with point and event params and wraps each feature' do
      all_events = 'Tornado Warning,Severe Thunderstorm Warning,' \
                   'Flash Flood Warning,Tornado Watch,Severe Thunderstorm Watch'
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
             .with(query: hash_including('point' => '40.688,-74.174', 'event' => all_events))
             .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })

      alerts = described_class.new.fetch(at: [40.688, -74.174])

      expect(stub).to have_been_requested
      expect(alerts.size).to eq(4)
      expect(alerts.map(&:event)).to include(
        'Tornado Warning', 'Severe Thunderstorm Warning', 'Flash Flood Warning', 'Tornado Watch'
      )
    end
  end

  describe '#fetch — edge cases' do
    it 'raises when events is empty' do
      expect { described_class.new.fetch(at: [0, 0], events: []) }
        .to raise_error(ArgumentError, /events must be non-empty/)
    end

    it 'forwards a custom events list to the query' do
      stub = stub_request(:get, 'https://api.weather.gov/alerts/active')
             .with(query: hash_including('event' => 'Tornado Warning'))
             .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      described_class.new.fetch(at: [0, 0], events: ['Tornado Warning'])

      expect(stub).to have_been_requested
    end

    it 'returns [] when NWS returns an empty FeatureCollection' do
      stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
        .to_return(status: 200, body: '{"features":[]}', headers: { 'Content-Type' => 'application/geo+json' })

      expect(described_class.new.fetch(at: [0, 0])).to eq([])
    end
  end
end
