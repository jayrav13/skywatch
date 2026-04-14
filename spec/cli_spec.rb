# frozen_string_literal: true

RSpec.describe Skywatch::Briefer::CLI do
  let(:kcdw_response) { [JSON.parse(File.read('spec/fixtures/metars/kcdw.json'))] }

  before do
    stub_request(:get, 'https://aviationweather.gov/api/data/metar')
      .with(query: { ids: 'KCDW', format: 'json' })
      .to_return(status: 200, body: kcdw_response.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe 'metar command' do
    it 'outputs text format by default' do
      output = capture_stdout { described_class.start(['metar', 'KCDW', '--format', 'text']) }
      expect(output).to include('KCDW')
      expect(output).to include('VFR')
      expect(output).to include('METAR KCDW')
    end

    it 'outputs JSON format' do
      output = capture_stdout { described_class.start(['metar', 'KCDW', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.first['station_id']).to eq('KCDW')
    end

    it 'outputs raw METAR only with --raw' do
      output = capture_stdout { described_class.start(['metar', 'KCDW', '--raw']) }
      raw_metar = 'METAR KCDW 280453Z 33003KT 10SM BKN070 04/M09 A3022 RMK AO2 SLP239 T00391089 401670039'
      expect(output.strip).to eq(raw_metar)
    end
  end

  describe 'taf command' do
    let(:kack_taf_response) { [JSON.parse(File.read('spec/fixtures/tafs/kack.json'))] }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/taf')
        .with(query: { ids: 'KACK', format: 'json' })
        .to_return(status: 200, body: kack_taf_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'outputs TAF in text format' do
      output = capture_stdout { described_class.start(['taf', 'KACK', '--format', 'text']) }
      expect(output).to include('KACK')
      expect(output).to include('TAF')
    end

    it 'outputs TAF in JSON format' do
      output = capture_stdout { described_class.start(['taf', 'KACK', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed.first['station_id']).to eq('KACK')
    end
  end

  describe 'pireps command' do
    let(:pirep_response) do
      [
        JSON.parse(File.read('spec/fixtures/pireps/icing.json')),
        JSON.parse(File.read('spec/fixtures/pireps/turbulence.json'))
      ]
    end

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/pirep')
        .with(query: { id: 'KCDW', dist: '100', format: 'json' })
        .to_return(status: 200, body: pirep_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'outputs PIREPs in text format' do
      output = capture_stdout { described_class.start(['pireps', 'KCDW', '--format', 'text']) }
      expect(output).to include('PIREPs within 100nm of KCDW')
      expect(output).to include('C17')
    end

    it 'outputs PIREPs in JSON format' do
      output = capture_stdout { described_class.start(['pireps', 'KCDW', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.size).to eq(2)
    end
  end

  describe 'sigmets command' do
    let(:active_sigmets) { JSON.parse(File.read('spec/fixtures/sigmets/active.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: active_sigmets.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'outputs SIGMETs in text format' do
      output = capture_stdout { described_class.start(['sigmets', '--format', 'text']) }
      expect(output).to include('SIGMET')
      expect(output).to include('CONVECTIVE')
    end

    it 'outputs SIGMETs in JSON format' do
      output = capture_stdout { described_class.start(['sigmets', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.size).to eq(2)
      expect(parsed.first['series_id']).to eq('3E')
    end

    it 'outputs no active message when empty' do
      Skywatch.reset!
      stub_request(:get, 'https://aviationweather.gov/api/data/airsigmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(['sigmets', '--format', 'text']) }
      expect(output).to include('No active SIGMETs')
    end
  end

  describe 'airmets command' do
    let(:gairmet_data) { JSON.parse(File.read('spec/fixtures/airmets/gairmet.json')) }

    before do
      stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: gairmet_data.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'outputs AIRMETs in text format' do
      output = capture_stdout { described_class.start(['airmets', '--format', 'text']) }
      expect(output).to include('AIRMET-SIERRA')
      expect(output).to include('AIRMET-TANGO')
      expect(output).to include('AIRMET-ZULU')
    end

    it 'outputs AIRMETs in JSON format' do
      output = capture_stdout { described_class.start(['airmets', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.size).to eq(3)
    end

    it 'filters by --product sierra' do
      output = capture_stdout { described_class.start(['airmets', '--product', 'sierra', '--format', 'text']) }
      expect(output).to include('AIRMET-SIERRA')
      expect(output).not_to include('AIRMET-ZULU')
      expect(output).not_to include('AIRMET-TANGO')
    end

    it 'filters by --product tango' do
      output = capture_stdout { described_class.start(['airmets', '--product', 'tango', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed.size).to eq(1)
      expect(parsed.first['product']).to eq('tango')
    end

    it 'outputs no active message when empty' do
      Skywatch.reset!
      stub_request(:get, 'https://aviationweather.gov/api/data/gairmet')
        .with(query: { format: 'json' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout { described_class.start(['airmets', '--format', 'text']) }
      expect(output).to include('No active AIRMETs')
    end
  end

  describe 'categories command' do
    it 'outputs flight categories in text format' do
      output = capture_stdout { described_class.start(['categories', 'KCDW', '--format', 'text']) }
      expect(output).to include('KCDW')
      expect(output).to include('VFR')
    end

    it 'outputs flight categories in JSON format' do
      output = capture_stdout { described_class.start(['categories', 'KCDW', '--format', 'json']) }
      parsed = JSON.parse(output)
      expect(parsed).to eq({ 'KCDW' => 'vfr' })
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
