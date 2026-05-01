# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe 'Skywatch.smoke' do
  let(:heavy_fixture) { File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json') }
  let(:empty_fixture) { File.read('spec/fixtures/hms_smoke/empty.json') }

  it 'delegates to Nimbus::Sources::Smoke#fetch and returns plumes' do
    stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
      .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

    plumes = Skywatch.smoke(at: [36.587, -121.843])

    expect(plumes).to all(be_a(Skywatch::Nimbus::Models::Smoke))
    expect(plumes.first.density_level).to eq(:heavy)
  end

  it 'returns [] when the source returns no features' do
    stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
      .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

    expect(Skywatch.smoke(at: [37.62, -122.38])).to eq([])
  end
end
