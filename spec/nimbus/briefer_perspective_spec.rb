# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'briefer-perspective convection output' do
  before do
    fixture = File.read(File.expand_path('../fixtures/nws_alerts/multiple_active.json', __dir__))
    stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
      .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })
  end

  it 'renders the convective section as briefer-cadence one-liners' do
    convection = Skywatch.convection(at: [40.688, -74.174])
    output = Skywatch::Nimbus::Formatters::Text.format_convection(convection)

    expected = <<~BRIEF
      TORNADO WARNING — Essex, NJ until 19:30Z. Radar-indicated; 1.50" hail, 65kt wind gust.
      SEVERE THUNDERSTORM WARNING — Bergen, NJ until 20:00Z. 1.00" hail, 52kt wind gust.
      FLASH FLOOD WARNING — Hudson, NJ until 23:00Z. Considerable damage threat.
      TORNADO WATCH #142 — NJ; NY; CT until 22:00Z.
    BRIEF

    expect(output).to eq(expected)
  end

  it 'emits the empty-state line when no convective alerts are active' do
    fixture = File.read(File.expand_path('../fixtures/nws_alerts/none_active.json', __dir__))
    stub_request(:get, %r{https://api\.weather\.gov/alerts/active})
      .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/geo+json' })

    convection = Skywatch.convection(at: [40.688, -74.174])
    output = Skywatch::Nimbus::Formatters::Text.format_convection(convection)

    expect(output).to eq("NO ACTIVE CONVECTIVE WARNINGS OR WATCHES.\n")
  end
end
