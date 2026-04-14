# frozen_string_literal: true

RSpec.describe Skywatch do
  describe '.metar' do
    let(:kcdw_data) { [JSON.parse(File.read('spec/fixtures/metars/kcdw.json'))] }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW', format: 'json' })
        .to_return(status: 200, body: kcdw_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Metar models' do
      metars = described_class.metar('KCDW')
      expect(metars).to be_an(Array)
      expect(metars.first).to be_a(Skywatch::Briefer::Models::Metar)
      expect(metars.first.station_id).to eq('KCDW')
      expect(metars.first.flight_category).to eq(:vfr)
    end
  end

  describe '.taf' do
    let(:kack_taf) { [JSON.parse(File.read('spec/fixtures/tafs/kack.json'))] }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/taf')
        .with(query: { ids: 'KACK', format: 'json' })
        .to_return(status: 200, body: kack_taf.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Taf models' do
      tafs = described_class.taf('KACK')
      expect(tafs.first).to be_a(Skywatch::Briefer::Models::Taf)
      expect(tafs.first.station_id).to eq('KACK')
      expect(tafs.first.forecast_groups).not_to be_empty
    end
  end

  describe '.pireps' do
    let(:pirep_data) { [JSON.parse(File.read('spec/fixtures/pireps/icing.json'))] }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/pirep')
        .with(query: { id: 'KCDW', dist: '100', format: 'json' })
        .to_return(status: 200, body: pirep_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Pirep models' do
      pireps = described_class.pireps('KCDW')
      expect(pireps.first).to be_a(Skywatch::Briefer::Models::Pirep)
    end
  end

  describe '.crosswind' do
    let(:kcdw_data) { [JSON.parse(File.read('spec/fixtures/metars/kcdw.json'))] }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/metar')
        .with(query: { ids: 'KCDW', format: 'json' })
        .to_return(status: 200, body: kcdw_data.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns crosswind and headwind components' do
      result = described_class.crosswind('KCDW', runway_heading: 280)
      expect(result).to have_key(:crosswind_kt)
      expect(result).to have_key(:headwind_kt)
    end
  end

  describe '.sigmets' do
    let(:active_sigmets) { JSON.parse(File.read('spec/fixtures/sigmets/active.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: active_sigmets.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns an array of Sigmet models' do
      sigs = described_class.sigmets
      expect(sigs).to be_an(Array)
      expect(sigs.first).to be_a(Skywatch::Briefer::Models::Sigmet)
    end
  end

  describe '.client' do
    it 'returns a lazy-initialized cached HTTP client' do
      expect(described_class.client).to be_a(Skywatch::Shared::Cache)
    end

    it 'returns the same instance on repeated calls' do
      expect(described_class.client).to be(described_class.client)
    end
  end

  describe '.reset!' do
    it 'clears the cached client' do
      first_client = described_class.client
      described_class.reset!
      expect(described_class.client).not_to be(first_client)
    end
  end
end
