# frozen_string_literal: true

RSpec.describe Skywatch::Mayday::CLI do
  let(:fixture) { File.read('spec/fixtures/opensky/states_bbox_emergencies.json') }

  before do
    stub_request(:get, 'https://opensky-network.org/api/states/all')
      .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
      .to_return(status: 200, body: fixture, headers: { 'Content-Type' => 'application/json' })
  end

  describe 'near command' do
    it 'prints emergencies in text format' do
      output = capture_stdout do
        described_class.start(['near', '40.875', '-74.282', '--radius', '50', '--format', 'text'])
      end
      expect(output).to include('MAYDAY: HIJACK (squawk 7500)')
      expect(output).to include('MAYDAY: RADIO FAILURE (squawk 7600)')
      expect(output).to include('MAYDAY: GENERAL EMERGENCY (squawk 7700)')
    end

    it 'prints emergencies in JSON format' do
      output = capture_stdout do
        described_class.start(['near', '40.875', '-74.282', '--radius', '50', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      expect(parsed.size).to eq(3)
      expect(parsed.map { |e| e['squawk'] }).to contain_exactly('7500', '7600', '7700')
    end

    it 'defaults the radius to 100nm' do
      output = capture_stdout do
        described_class.start(['near', '40.875', '-74.282', '--format', 'json'])
      end
      parsed = JSON.parse(output)
      callsigns = parsed.map { |e| e['callsign'] }
      expect(callsigns).to include('FAR0005')
    end

    it 'prints a friendly empty-state message in text format' do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
        .to_return(status: 200, body: { 'time' => 0, 'states' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout do
        described_class.start(['near', '0.0', '0.0', '--radius', '50', '--format', 'text'])
      end
      expect(output).to include('No emergencies within 50nm of 0.0, 0.0')
    end

    it 'prints [] in JSON format when there are no emergencies' do
      stub_request(:get, 'https://opensky-network.org/api/states/all')
        .with(query: hash_including('lamin', 'lamax', 'lomin', 'lomax'))
        .to_return(status: 200, body: { 'time' => 0, 'states' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      output = capture_stdout do
        described_class.start(['near', '0.0', '0.0', '--radius', '50', '--format', 'json'])
      end
      expect(output.strip).to eq('[]')
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
