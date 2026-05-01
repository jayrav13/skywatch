# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe Skywatch::Nimbus::Sources::Smoke do
  let(:heavy_fixture) { File.read('spec/fixtures/hms_smoke/heavy_smoke_at_kmry.json') }
  let(:empty_fixture) { File.read('spec/fixtures/hms_smoke/empty.json') }

  let(:base_url) do
    'https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/' \
      'NOAA_Satellite_Smoke_Detection_(v1)/FeatureServer/0/query'
  end

  describe '#fetch' do
    it 'requests the ArcGIS query endpoint with point-intersect params and wraps each feature' do
      stub = stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
             .with(query: hash_including(
               'geometry' => '-121.843,36.587',
               'geometryType' => 'esriGeometryPoint',
               'inSR' => '4326',
               'spatialRel' => 'esriSpatialRelIntersects',
               'outFields' => '*',
               'f' => 'json'
             ))
             .to_return(status: 200, body: heavy_fixture, headers: { 'Content-Type' => 'application/json' })

      plumes = described_class.new.fetch(at: [36.587, -121.843])

      expect(stub).to have_been_requested
      expect(plumes.size).to eq(1)
      expect(plumes.first.density_raw).to eq('Heavy')
      expect(plumes.first.satellite).to eq('GOES-EAST')
    end

    it 'returns [] when ArcGIS returns an empty FeatureCollection' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 200, body: empty_fixture, headers: { 'Content-Type' => 'application/json' })

      expect(described_class.new.fetch(at: [37.62, -122.38])).to eq([])
    end

    it 'raises Skywatch::ApiError on a non-200 response' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query})
        .to_return(status: 500, body: '{"error":{"code":500,"message":"server boom"}}')

      expect { described_class.new.fetch(at: [37.62, -122.38]) }
        .to raise_error(Skywatch::ApiError)
    end

    it 'raises Skywatch::ConnectionError on a network failure' do
      stub_request(:get, %r{services2\.arcgis\.com.*FeatureServer/0/query}).to_timeout

      expect { described_class.new.fetch(at: [37.62, -122.38]) }
        .to raise_error(Skywatch::ConnectionError)
    end
  end
end
