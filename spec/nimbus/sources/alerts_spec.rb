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
end
